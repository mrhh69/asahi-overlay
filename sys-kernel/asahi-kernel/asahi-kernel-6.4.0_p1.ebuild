# Copyright 2020-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit kernel-build #toolchain-funcs

MY_TAG="$(ver_cut 5)"
MY_P="asahi-$(ver_cut 1-2)-${MY_TAG}"

DESCRIPTION="Build downstream Asahi Linux"
HOMEPAGE="https://asahilinux.org"
LICENSE="GPL-2"
SRC_URI+="
https://github.com/AsahiLinux/linux/archive/refs/tags/${MY_P}.tar.gz
https://raw.githubusercontent.com/AsahiLinux/PKGBUILDs/main/linux-asahi/config
https://raw.githubusercontent.com/AsahiLinux/PKGBUILDs/main/linux-asahi/config.edge
"
S=${WORKDIR}/linux-${MY_P}

PATCHES=(
#	"${FILESDIR}"/rustavial.patch
	"${FILESDIR}"/bindgen.patch
)

KEYWORDS="~arm64"
IUSE="experimental"

#BDEPEND="
#	debug? ( dev-util/pahole )
#"
#PDEPEND="
#	>=virtual/dist-kernel-${PV}
#"

src_prepare() {
	# voodoo magic: my brain is in pain because `default` doesn't work but `eapply` does
	eapply "${FILESDIR}"/rustavail.patch
	default

	cp "${DISTDIR}/config" .config || die

	local myversion="-${MY_TAG}-dist"
	use experimental && myversion+="-edge"
	echo "CONFIG_LOCALVERSION=\"${myversion}\"" > "${T}"/version.config || die

	local merge_configs=()
	use experimental && merge_configs+=("${DISTDIR}/config.edge")

	local merge_configs+=("${T}"/version.config)

	kernel-build_merge_configs "${merge_configs[@]}"
}

#src_configure() {
#	default
#	# sanity check for testing: maybe remove once BDEPS is sorted out
#	use experimental && emake rustavailable || die
#}
