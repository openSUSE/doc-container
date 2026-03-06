#!BuildTag: opensuse-daps-toolchain
#!BuildTag: opensuse-daps-toolchain:%RELEASE%

# For ideas:
# https://build.opensuse.org/package/show/home:darix:apps/container-gitlab-runner
ARG RELEASE=15.6
FROM opensuse/leap:$RELEASE

ARG URL=https://download.opensuse.org/repositories


# Define labels according to https://en.opensuse.org/Building_derived_containers
# labelprefix=org.opensuse.daps-toolchain
PREFIXEDLABEL org.opencontainers.image.title="DAPS container for XML validation"
PREFIXEDLABEL org.opencontainers.image.description="Container daps-toolchain %PKG_VERSION%"
PREFIXEDLABEL org.opensuse.reference="registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest"
PREFIXEDLABEL org.openbuildservice.disturl="%DISTURL%"
PREFIXEDLABEL org.opencontainers.image.created="%BUILDTIME%"
PREFIXEDLABEL org.opencontainers.image.authors="SUSE Documentation Team <doc-team@suse.com>"


# Repositories from the project config are used by default.
#
# Put additional files into container
COPY rm-packages \
     rm-files \
       /root/

# cleanup the previously existing .repo files and add those that the
# distribution itself uses, ensuring a correct repository configuration
RUN zypper --non-interactive in live-add-yast-repos && \
    rm /etc/zypp/repos.d/repo*repo && \
    add-yast-repos && zypper -n ref && \
    zypper --non-interactive rm live-add-yast-repos

# zypper ar $URL/Java:/packages/SLE_15_SP2/ "OBS:Java";
# zypper ar $URL/Documentation:Tools/$releasever "DocTools";
# zypper ar $URL/M17N:/fonts/'$releasever'/ "M17N:fonts"; \
RUN \
  zypper ar $URL/Documentation:/Containers/openSUSE_Leap_'$releasever'/ "DocCont-Leap"; \
  zypper ar $URL/Documentation:/Tools/'$releasever' "DocTools"; \
  zypper --gpg-auto-import-keys ref


# Install packages
#
# sgml-skel needs to be installed first, as it contains the
# `update-xml-catalogs` script which is needed during package build
#
# this layer adds the bulk of items to the container: we try to do
# additions/deletions all at once to avoid layering deletions on top of
# additions which would result in a container that is larger, not smaller
RUN \
  zypper --non-interactive install -y sgml-skel

# Explicitly install the fonts we need from our own repository
RUN zypper --non-interactive install --no-recommends --no-confirm \
    # we need to be more explict as suse-xsl-stylesheets changed dependency
    # from requires -> recommends
    google-noto-sans-jp-regular-fonts google-noto-sans-jp-bold-fonts \
    google-noto-sans-sc-regular-fonts google-noto-sans-sc-bold-fonts \
    google-noto-sans-kr-regular-fonts google-noto-sans-kr-bold-fonts \
    google-noto-sans-tc-regular-fonts google-noto-sans-tc-bold-fonts \
    arabic-amiri-fonts \
    sil-charis-fonts gnu-free-fonts google-opensans-fonts dejavu-fonts google-poppins-fonts

RUN \
  zypper --non-interactive install --no-recommends --no-confirm \
            vim-small \
            curl \
            daps \
            ditaa \
            geekodoc \
            git \
            gzip \
            libreoffice-draw \
            novdoc \
            ruby2.5-rubygem-asciidoctor \
            suse-xsl-stylesheets \
            suse-xsl-stylesheets-sbp \
            python3-base \
            tar \
            w3m \
            jq \
            rsvg-convert \
            openssh-clients \
	    suse-fonts ; \
  zypper clean --all; \
  xargs rpm --erase --nodeps < /root/rm-packages; \
  xargs rm -rf < /root/rm-files; \
  rm /root/rm-packages /root/rm-files

RUN \
  mkdir --parents /root/.config/daps; \
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rng:v2:geekodoc-flat"' > /root/.config/daps/dapsrc

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM xterm-256color
