#!BuildTag: opensuse-daps-toolchain
#!BuildTag: opensuse-daps-toolchain:%RELEASE%

ARG RELEASE=16.0
FROM opensuse/leap:$RELEASE

# Re-declare ARG after FROM
ARG RELEASE=16.0
ARG URL=https://download.opensuse.org/repositories

LABEL org.opencontainers.image.title="DAPS container for XML validation"
LABEL org.opencontainers.image.description="Container daps-toolchain %PKG_VERSION%"
LABEL org.opensuse.reference="registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest"
LABEL org.openbuildservice.disturl="%DISTURL%"
LABEL org.opencontainers.image.created="%BUILDTIME%"
LABEL org.opencontainers.image.authors="SUSE Documentation Team <doc-team@suse.com>"

COPY rm-packages \
     rm-files \
       /root/

# Optimization: Consolidate all setup, installation, and cleanup into a single RUN block.
# This prevents temporary files, caches, and intermediate metadata from persisting in layers.
# Trimmed the font list to include only Regular Sans variants for CJK languages
# and explicitly use the headless JRE to keep the footprint as small as possible.

RUN \
  # 1. Cleanup existing repos and add new ones (restoring repo-oss deleted by cleanup)
  zypper --non-interactive clean --all && \
  rm -f /etc/zypp/repos.d/repo*repo && \
  zypper ar https://download.opensuse.org/distribution/leap/${RELEASE}/repo/oss/ repo-oss && \
  zypper ar ${URL}/Documentation:/Containers/openSUSE_Leap_${RELEASE}/ DocCont && \
  zypper ar -f ${URL}/Documentation:/Tools/${RELEASE}/ DocTools && \
  zypper --gpg-auto-import-keys ref -f && \
  \
  # 2. Install sgml-skel (needed for package build catalogs)
  zypper --non-interactive install --allow-vendor-change -y sgml-skel && \
  \
  # 3. Install Fonts (Retry loop for transient network errors)
  # Use only Regular-Sans variants for CJK to save ~350MB.
  for i in {1..5}; do \
    zypper --non-interactive install --no-recommends --no-confirm \
    google-noto-sans-jp-regular-fonts \
    google-noto-sans-sc-regular-fonts \
    google-noto-sans-kr-regular-fonts \
    google-noto-sans-tc-regular-fonts \
    arabic-amiri-fonts \
    sil-charis-fonts gnu-free-fonts google-opensans-fonts dejavu-fonts google-poppins-fonts && \
    break || sleep 5; \
  done && \
  \
  # 4. Install Toolchain, Python, and Basics
  # Optimization: Explicitly use java-17-openjdk-headless to avoid GUI/X11 bloat for ditaa.
  zypper --non-interactive install --allow-vendor-change --no-recommends -y \
    vim-small curl git gzip tar w3m jq rsvg-convert openssh-clients suse-fonts \
    python3 python3-pip \
    java-17-openjdk-headless daps ditaa geekodoc novdoc suse-xsl-stylesheets "rubygem(asciidoctor)" && \
  \
  # 5. Cleanup and Symlinks
  if [ ! -L /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi; \
  \
  # Aggressive removal of unneeded files and caches before layer is finalized
  zypper clean --all && \
  xargs rpm --erase --nodeps < /root/rm-packages || true && \
  xargs rm -rf < /root/rm-files || true && \
  rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* /var/cache/zypp/* /root/rm-packages /root/rm-files

RUN \
  mkdir --parents /root/.config/daps; \
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rng:v2:geekodoc-flat"' > /root/.config/daps/dapsrc

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color