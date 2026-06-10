# Stable build environment for buildroot (Arch hosts are too rolling).
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        bc \
        build-essential \
        bzip2 \
        ca-certificates \
        cpio \
        file \
        git \
        libgnutls28-dev \
        libncurses-dev \
        libssl-dev \
        uuid-dev \
        locales \
        patch \
        perl \
        python3 \
        rsync \
        unzip \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen

ENV LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

CMD ["/bin/bash"]
