#!BuildTag: opensuse-daps-toolchain
#!BuildTag: opensuse-daps-toolchain:%RELEASE%

ARG RELEASE=16.0
FROM opensuse/leap:$RELEASE

# Re-declare ARG after FROM
ARG RELEASE=16.0
ARG URL=https://download.opensuse.org/repositories
ARG PYTHON_VERSION=3.12

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
# Install packages
#
# sgml-skel needs to be installed first, as it contains the
# `update-xml-catalogs` script which is needed during package build
#
# this layer adds the bulk of items to the container: we try to do
# additions/deletions all at once to avoid layering deletions on top of
# additions which would result in a container that is larger, not smaller
#
# live-add-yast-repos is replaced by direct repo management for Leap 16.0
RUN zypper --non-interactive clean --all && \
    rm -f /etc/zypp/repos.d/repo*repo && \
    zypper -n ref

# Add repositories. 
# For Leap 16.0 (Tumbleweed-based), we use the Tumbleweed targets.
# We use the generic 'python' repo instead of 'backports' for 16.0/TW.
RUN \
  zypper ar ${URL}/Documentation:/Containers/openSUSE_Leap_15.6/ DocCont-Fallback && \
  zypper ar ${URL}/Documentation:/Tools/openSUSE_Tumbleweed/ DocTools && \
  zypper ar ${URL}/devel:/languages:/python/openSUSE_Tumbleweed/ Python-Languages && \
  zypper --gpg-auto-import-keys ref

RUN zypper --non-interactive install -y sgml-skel
# Explicitly install fonts - including the 'un-fonts' capability needed by suse-xsl-stylesheets
RUN zypper --non-interactive install --no-recommends --no-confirm \
    google-noto-sans-jp-regular-fonts google-noto-sans-jp-bold-fonts \
    google-noto-sans-sc-regular-fonts google-noto-sans-sc-bold-fonts \
    google-noto-sans-kr-regular-fonts google-noto-sans-kr-bold-fonts \
    google-noto-sans-tc-regular-fonts google-noto-sans-tc-bold-fonts \
    arabic-amiri-fonts \
    sil-charis-fonts gnu-free-fonts google-opensans-fonts dejavu-fonts google-poppins-fonts \
    google-noto-serif-kr-fonts

# Toolchain and Python installation
# 1. Test Repository Connectivity
RUN zypper lr -d

# 2. Try to install just the basics first
RUN zypper --non-interactive install --no-recommends --no-confirm -y \
    vim-small curl git gzip tar w3m jq rsvg-convert openssh-clients suse-fonts

# 3. Try to install Python
RUN zypper --non-interactive install --no-recommends --no-confirm -y \
    python3.12 python312-pip || zypper --non-interactive install --no-recommends --no-confirm -y python3 python3-pip

# 4. Try to install the DAPS toolchain
RUN zypper -n install --no-recommends -y ditaa geekodoc novdoc suse-xsl-stylesheets libreoffice-draw rubygem-asciidoctor || \
    zypper -n install --no-recommends -y ditaa geekodoc novdoc suse-xsl-stylesheets libreoffice-draw ruby3.4-rubygem-asciidoctor || \
    zypper -n install --no-recommends -y ditaa geekodoc novdoc suse-xsl-stylesheets libreoffice-draw ruby3.3-rubygem-asciidoctor

# Force-install DAPS by fetching the RPM directly to bypass the Ruby 4.0 solver error.
RUN DAPS_RPM=$(curl -sL https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Tumbleweed/noarch/ | grep -o 'daps-[0-9][^"]*\.noarch\.rpm' | head -n 1) && \
    rpm -ivh --nodeps https://download.opensuse.org/repositories/Documentation:/Tools/openSUSE_Tumbleweed/noarch/$DAPS_RPM

# 5. Cleanup and Symlinks
RUN \
  PYTHON_BIN=$(ls /usr/bin/python3.[0-9]* 2>/dev/null | head -n 1); \
  if [ -n "$PYTHON_BIN" ]; then ln -sf "$PYTHON_BIN" /usr/bin/python3; fi; \
  ASCIIDOC_REAL=$(find /usr/bin -type f -name "asciidoctor*" | sort -V | tail -n 1); \
  if [ -n "$ASCIIDOC_REAL" ]; then ln -sf "$ASCIIDOC_REAL" /usr/bin/asciidoctor; fi; \
  if [ ! -x /usr/bin/asciidoctor ]; then \
    ASCIIDOC_GEM=$(find /usr/lib*/ruby/gems -name asciidoctor -type f -executable | head -n 1); \
    if [ -n "$ASCIIDOC_GEM" ]; then ln -sf "$ASCIIDOC_GEM" /usr/bin/asciidoctor; fi; \
  fi; \
  zypper clean --all; \
  xargs rpm --erase --nodeps < /root/rm-packages || true; \
  xargs rm -rf < /root/rm-files || true; \
  rm /root/rm-packages /root/rm-files

RUN \
  mkdir --parents /root/.config/daps; \
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rng:v2:geekodoc-flat"' > /root/.config/daps/dapsrc

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color