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
# Note: For Leap 16.0, the naming convention in OBS has moved from 
# 'openSUSE_Leap_16.0' to just '16.0' as per reviewer feedback.
# We explicitly add repo-oss back because the cleanup step above removes it.
# We use -f (force) for DocTools to bypass caching issues with the ditaa package.
RUN \
  zypper ar https://download.opensuse.org/distribution/leap/${RELEASE}/repo/oss/ repo-oss && \
  zypper ar ${URL}/Documentation:/Containers/openSUSE_Leap_${RELEASE}/ DocCont && \
  zypper ar -f ${URL}/Documentation:/Tools/${RELEASE}/ DocTools && \
  zypper --gpg-auto-import-keys ref -f

# sgml-skel needs --allow-vendor-change because it might exist in multiple repos
RUN zypper --non-interactive install --allow-vendor-change -y sgml-skel

# Explicitly install fonts - including the 'un-fonts' capability needed by suse-xsl-stylesheets
# We use a retry loop to mitigate transient SSL/EOF network errors during the 16.0 bootstrap
RUN for i in {1..5}; do \
    zypper --non-interactive install --no-recommends --no-confirm \
    google-noto-sans-jp-regular-fonts google-noto-sans-jp-bold-fonts \
    google-noto-sans-sc-regular-fonts google-noto-sans-sc-bold-fonts \
    google-noto-sans-kr-regular-fonts google-noto-sans-kr-bold-fonts \
    google-noto-sans-tc-regular-fonts google-noto-sans-tc-bold-fonts \
    arabic-amiri-fonts \
    sil-charis-fonts gnu-free-fonts google-opensans-fonts dejavu-fonts google-poppins-fonts \
    google-noto-serif-kr-fonts && break || sleep 5; \
    done

# Toolchain and Python installation
# 1. List repos
RUN zypper lr -d

# 2. Install basics
RUN zypper --non-interactive install --no-recommends -y \
    vim-small curl git gzip tar w3m jq rsvg-convert openssh-clients suse-fonts

# 3. Install Python
# Using generic python3 package as per Leap 16.0 defaults
RUN zypper --non-interactive install --no-recommends --no-confirm -y python3 python3-pip

# 4. Install the DAPS toolchain
# We use symbolic capabilities and native 16.0 repositories.
# We include "rubygem(asciidoctor)" to allow zypper to resolve the Ruby provider.
# We use --allow-vendor-change to handle overlapping packages between OSS and DocTools.
RUN zypper -n install --allow-vendor-change --no-recommends -y \
    daps \
    ditaa \
    geekodoc \
    novdoc \
    suse-xsl-stylesheets \
    "rubygem(asciidoctor)"

# 5. Cleanup and Symlinks
RUN \
  # Standardize python command
  if [ ! -L /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi; \
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