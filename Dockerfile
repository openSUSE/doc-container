#!BuildTag: opensuse-daps-toolchain
#!BuildTag: opensuse-daps-toolchain:%RELEASE%

## Global declaration (Before any FROM keywords)
ARG RELEASE=16.0
ARG URL=https://download.opensuse.org/repositories

# ---------------------------------------------------------
# --- Stage 1: Slim / Validation ---
# ---------------------------------------------------------
FROM opensuse/leap:$RELEASE AS daps-slim

# Re-define ARG after FROM
ARG RELEASE
ARG URL

LABEL org.opencontainers.image.title="DAPS slim container for XML validation"
LABEL org.opencontainers.image.description="Container daps-toolchain %PKG_VERSION% (Slim)"
LABEL org.opensuse.reference="registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain-slim:latest"
LABEL org.openbuildservice.disturl="%DISTURL%"
LABEL org.opencontainers.image.created="%BUILDTIME%"
LABEL org.opencontainers.image.authors="SUSE Documentation Team <doc-team@suse.com>"

COPY rm-packages \
     rm-files \
       /root/

# Optimization: Consolidate all setup, installation, and cleanup into a single RUN block.
# This prevents temporary files, caches, and intermediate metadata from persisting in layers.
# This stage (Slim) focuses ONLY on validation essentials to minimize CI download time.

RUN \
  # 1. Cleanup existing repos and add new ones
  #
  # # Add repositories. 
  # # Note: For Leap 16.0, the naming convention in OBS has moved from 
  # # 'openSUSE_Leap_16.0' to just '16.0' as per reviewer feedback.
  # # We explicitly add repo-oss back because the cleanup step above removes it.
  # # We use -f (force) for DocTools to bypass caching issues with the ditaa package.
  #
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
  # 3. Install Toolchain, Python, and Basics (Slim version)
  # We exclude heavy fonts and Java from this stage to keep it lightweight.
  zypper --non-interactive install --allow-vendor-change --no-recommends -y \
    vim-small curl git gzip tar jq python3 python3-pip \
    daps geekodoc novdoc "rubygem(asciidoctor)" && \
    \
  # 4. Cleanup
  # We rely on the rm-files list for directory pruning to keep the RUN block clean.
  zypper clean --all && \
  xargs rm -rf < /root/rm-files || true

# ---------------------------------------------------------
# --- Stage 2: Full Toolchain ---
# ---------------------------------------------------------
FROM daps-slim AS daps-full

# Re-define ARG after FROM
ARG RELEASE
ARG URL

LABEL org.opencontainers.image.title="DAPS full container for building"
LABEL org.opencontainers.image.description="Container daps-toolchain %PKG_VERSION% (Full)"
LABEL org.opensuse.reference="registry.opensuse.org/documentation/containers/containers/opensuse-daps-toolchain:latest"

# Optimization: Inherit from daps-slim and add heavy building components (Fonts + Java).
# Per reviewer feedback, we must include bold versions of CJK fonts to ensure
# correct PDF rendering, even if it increases the "Full" image size.

RUN \
  # Refresh keys for any new additions in this stage
  zypper --gpg-auto-import-keys ref && \
  \
  # 1. Install Fonts (Retry loop for transient network errors)
  # Including Bold variants as they are required for PDF generation.
  for i in {1..5}; do \
    zypper --non-interactive install --no-recommends --no-confirm \
    google-noto-sans-jp-regular-fonts google-noto-sans-jp-bold-fonts \
    google-noto-sans-sc-regular-fonts google-noto-sans-sc-bold-fonts \
    google-noto-sans-kr-regular-fonts google-noto-sans-kr-bold-fonts \
    google-noto-sans-tc-regular-fonts google-noto-sans-tc-bold-fonts \
    arabic-amiri-fonts \
    sil-charis-fonts gnu-free-fonts google-opensans-fonts dejavu-fonts google-poppins-fonts && \
    break || sleep 5; \
  done && \
  \
  # 2. Install Build-Specific Toolchain
  # Optimization: Explicitly use java-17-openjdk-headless to avoid GUI/X11 bloat for ditaa.
  zypper --non-interactive install --allow-vendor-change --no-recommends -y \
    w3m rsvg-convert openssh-clients suse-fonts \
    java-17-openjdk-headless ditaa suse-xsl-stylesheets && \
  \
  # 3. Final Aggressive removal of unneeded files and caches
  # We process the rm-files list which handles system documentation and cache paths.
  zypper clean --all && \
  xargs rpm --erase --nodeps < /root/rm-packages || true && \
  xargs rm -rf < /root/rm-files || true && \
  rm -rf /root/rm-packages /root/rm-files

RUN \
  mkdir --parents /root/.config/daps; \
  echo 'DOCBOOK5_RNG_URI="urn:x-suse:rng:v2:geekodoc-flat"' > /root/.config/daps/dapsrc

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color