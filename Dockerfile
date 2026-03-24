#!BuildTag: opensuse-daps-toolchain
#!BuildTag: opensuse-daps-toolchain:%RELEASE%

ARG RELEASE=15.6
FROM opensuse/leap:$RELEASE

# Re-declare ARG after FROM
ARG RELEASE=15.6
ARG URL=https://download.opensuse.org/repositories
ARG PYTHON_VERSION=312

LABEL org.opencontainers.image.title="DAPS container for XML validation"
LABEL org.opencontainers.image.description="Container daps-toolchain %PKG_VERSION%"
LABEL org.opensuse.reference="registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest"
LABEL org.openbuildservice.disturl="%DISTURL%"
LABEL org.opencontainers.image.created="%BUILDTIME%"
LABEL org.opencontainers.image.authors="SUSE Documentation Team <doc-team@suse.com>"

COPY rm-packages \
     rm-files \
       /root/

# Cleanup and setup repos
RUN zypper --non-interactive in live-add-yast-repos && \
    rm /etc/zypp/repos.d/repo*repo && \
    add-yast-repos && zypper -n ref && \
    zypper --non-interactive rm live-add-yast-repos

# Add repositories. 
# Using the python:backports repository which is the standard for Leap 15.x modern python
RUN \
  zypper ar ${URL}/Documentation:/Containers/openSUSE_Leap_${RELEASE}/ DocCont-Leap && \
  zypper ar ${URL}/Documentation:/Tools/${RELEASE}/ DocTools && \
  zypper ar ${URL}/devel:/languages:/python:/backports/openSUSE_Leap_${RELEASE}/ Python-Backports && \
  zypper --gpg-auto-import-keys ref

RUN zypper --non-interactive install -y sgml-skel

RUN zypper --non-interactive install --no-recommends --no-confirm \
    google-noto-sans-jp-regular-fonts google-noto-sans-jp-bold-fonts \
    google-noto-sans-sc-regular-fonts google-noto-sans-sc-bold-fonts \
    google-noto-sans-kr-regular-fonts google-noto-sans-kr-bold-fonts \
    google-noto-sans-tc-regular-fonts google-noto-sans-tc-bold-fonts \
    arabic-amiri-fonts \
    sil-charis-fonts gnu-free-fonts google-opensans-fonts dejavu-fonts google-poppins-fonts

# Toolchain and Python installation
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
            python${PYTHON_VERSION} \
            python${PYTHON_VERSION}-pip \
            tar \
            w3m \
            jq \
            rsvg-convert \
            openssh-clients \
            suse-fonts ; \
  # Fix symlink for python3
  ln -sf /usr/bin/python3.12 /usr/bin/python3; \
  zypper clean --all; \
  xargs rpm --erase --nodeps < /root/rm-packages; \
  xargs rm -rf < /root/rm-files; \
  rm /root/rm-packages /root/rm-files

RUN \
  mkdir --parents /root/.config/daps; \
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rng:v2:geekodoc-flat"' > /root/.config/daps/dapsrc

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color