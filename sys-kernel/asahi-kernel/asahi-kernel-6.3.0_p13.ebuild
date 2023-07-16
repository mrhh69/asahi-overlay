# license here ig
# written by mrhh69

EAPI=8
SLOT=13

DESCRIPTION="Build downstream Asahi Linux"
HOMEPAGE="https://asahilinux.org"

MY_TAG="$(ver_cut 5)"
MY_P="asahi-$(ver_cut 1-2)-${MY_TAG}"

# idk if I should really tie the configs to the main branch
SRC_URI="
https://github.com/AsahiLinux/linux/archive/refs/tags/${MY_P}.tar.gz
https://raw.githubusercontent.com/AsahiLinux/PKGBUILDs/main/linux-asahi/config
https://raw.githubusercontent.com/AsahiLinux/PKGBUILDs/main/linux-asahi/config.edge
"

PATCHES=(
	"${FILESDIR}"/${PVR}-bindgen.patch
)

IUSE="experimental"
KEYWORDS="~arm64"

# NOTE: it seems that with newer clang versions (1.16)
# that the old bindgen-0.56.0 that I was using no longer works
# So, the patch is needed to bring up bindgen, but bindgen-0.65.1
# is not in the gentoo tree (latest version is 0.63.0), so :shrug:
# TODO: find out what stuff I need to build kernel (4got)
# also need to figure out if requiring use flags directly from dev-lang/rust is right
BDEPEND="
	experimental? (
		>=virtual/rust-1.66.0
		dev-lang/rust[rust-src]
	)
"

src_unpack() {
	unpack ${MY_P}.tar.gz
	# fix this wildcard to point to actual file
	mv "${WORKDIR}"/* "${WORKDIR}"/${PF}
}

src_prepare() {
	default

	cp "${DISTDIR}"/config .config
	use experimental && cat "${DISTDIR}"/config.edge >> .config
	echo "CONFIG_LOCALVERSION=\"$(use experimental && echo -edge)-dist\"" >> .config

	echo "-${MY_TAG}" > localversion.10-revision
}

src_configure() {
	use experimental && emake rustavailable || die
	emake olddefconfig
}

src_compile() {
	MAKEARGS=()
	use experimental && MAKEARGS+=(LLVM=1)

	emake ${MAKEARGS[@]}
}

src_install() {

	# install modules and kernel image
	dodir /boot
	emake "${MAKEARGS[@]}" \
		INSTALL_MOD_PATH="${ED}" \
		INSTALL_PATH="${ED}/boot" \
		modules_install install

	# install needed kernel source files
	#
	# maybe figure out what other stuff has to go into /usr/src?
	# is it just the 'include's?
	local kernel_rel=$(make kernelrelease)
	local kernel_dir=/usr/src/linux-${kernel_rel}
	local td=${ED}/${kernel_dir}
	# NOTE(self): why doesn't gentoo have an install command to automatically to `insinto`, am I blind?
	insinto ${kernel_dir}
	doins -r include scripts
	insinto ${kernel_dir}/arch/arm64/
	doins -r arch/arm64/include
	# for update-m1n1
	insinto ${kernel_dir}/arch/arm64/boot/dts/apple/
	doins arch/arm64/boot/dts/apple/*.dtb

	find -type f '!' '(' -name 'Makefile*' -o -name 'Kconfig*' ')' \
		-delete
	find -type l -delete
	insinto ${kernel_dir}
	doins -r *
	# cp -p -R * "${td}" || die

	# fix source tree and build dir symlinks
	dosym "../../../${kernel_dir}" "/lib/modules/${kernel_rel}/build"
	dosym "../../../${kernel_dir}" "/lib/modules/${kernel_rel}/source"

	# initramfs (dracut)

	# should I use the installed global modules for dracut, or local ones?
	# (look at the --local flag again)
	# ldconfig seems to be violating the gentoo sandbox, this is a _really_ ugly hack
	DRACUT_LDCONFIG=true dracut "${ED}"/boot/initramfs-${kernel_rel}.img ${kernel_rel} \
		--tmpdir "${T}" \
		--kmoddir "${ED}"/lib/modules/${kernel_rel} \
		--compress gzip \
		|| die
}
