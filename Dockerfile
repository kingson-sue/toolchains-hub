# Toolchains Hub（可迁移）
# 镜像只含 OS 依赖 + SSH；IDF 源码与工具链在 data/ 中通过 volume 挂载
#
# BASE_IMAGE 可通过 --build-arg 覆盖（国内拉不动 Docker Hub 时用镜像站）
ARG BASE_IMAGE=docker.m.daocloud.io/library/ubuntu:22.04
ARG CONTAINER_HOME=/toolchain
ARG CONTAINER_USER=toolchain
ARG SSH_PASSWORD=toolchain168

FROM ${BASE_IMAGE}

ARG CONTAINER_HOME=/toolchain
ARG CONTAINER_USER=toolchain
ARG SSH_PASSWORD=toolchain168

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Shanghai \
    HOME=${CONTAINER_HOME} \
    CONTAINER_HOME=${CONTAINER_HOME} \
    CONTAINER_USER=${CONTAINER_USER}

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        bash-completion \
        wget \
        curl \
        flex \
        bison \
        gperf \
        python3 \
        python3-pip \
        python3-venv \
        python3-setuptools \
        python3-dev \
        cmake \
        ninja-build \
        ccache \
        libffi-dev \
        libssl-dev \
        dfu-util \
        libusb-1.0-0 \
        openssh-server \
        sudo \
        ca-certificates \
        vim \
        nano \
        less \
        rsync \
        unzip \
        pkg-config \
        build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/run/sshd \
    && useradd -m -d "${CONTAINER_HOME}" -s /bin/bash "${CONTAINER_USER}" \
    && usermod -aG sudo "${CONTAINER_USER}" \
    && ssh-keygen -A \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd \
    && echo "root:${SSH_PASSWORD}" | chpasswd \
    && echo "${CONTAINER_USER}:${SSH_PASSWORD}" | chpasswd \
    && printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${CONTAINER_USER}" > "/etc/sudoers.d/${CONTAINER_USER}" \
    && chmod 0440 "/etc/sudoers.d/${CONTAINER_USER}" \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && printf 'export HOME=%s\nexport CONTAINER_HOME=%s\ncd %s/workspace 2>/dev/null || true\n' \
        "${CONTAINER_HOME}" "${CONTAINER_HOME}" "${CONTAINER_HOME}" \
        > /etc/profile.d/toolchain-home.sh

COPY rootfs/ /
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R "${CONTAINER_USER}:${CONTAINER_USER}" "${CONTAINER_HOME}" \
    && if [ -f "${CONTAINER_HOME}/.bashrc" ]; then ln -sf "${CONTAINER_HOME}/.bashrc" /root/.bashrc; fi \
    && if [ -f "${CONTAINER_HOME}/.profile" ]; then ln -sf "${CONTAINER_HOME}/.profile" /root/.profile; fi

EXPOSE 22
WORKDIR ${CONTAINER_HOME}/workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
