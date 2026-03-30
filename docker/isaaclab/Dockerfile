ARG BASE_IMAGE=wtyyy/ubuntu:24.04
FROM ${BASE_IMAGE}

ARG DEFAULT_USER=user
ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ARG DEFAULT_HOME=/home/user
ARG UV_ENV_NAME=isaaclab
ARG PYTHON_VERSION=3.11
ARG TORCH_VERSION=2.7.0
ARG TORCHVISION_VERSION=0.22.0
ARG ISAACLAB_VERSION=2.3.2.post1

ENV DEBIAN_FRONTEND=noninteractive
ENV UV_LINK_MODE=copy
ENV HOME=${DEFAULT_HOME}
ENV PATH=${DEFAULT_HOME}/.local/bin:${DEFAULT_HOME}/${UV_ENV_NAME}/bin:${PATH}

RUN set -eux; \
    install -d -m 0755 "${DEFAULT_HOME}"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

RUN set -eux; \
    uv venv "${UV_ENV_NAME}" --python "${PYTHON_VERSION}" --seed; \
    . "${UV_ENV_NAME}/bin/activate"; \
    uv pip install -U "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" --index-url https://download.pytorch.org/whl/cu128; \
    pip install "isaaclab[isaacsim,all]==${ISAACLAB_VERSION}" --extra-index-url https://pypi.nvidia.com

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libgomp1 libglu1; \
    apt-get update; \
    apt-get install -y --no-install-recommends mesa-utils vulkan-tools x11-apps; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    chown -R "${DEFAULT_UID}:${DEFAULT_GID}" "${DEFAULT_HOME}"

USER root
WORKDIR ${DEFAULT_HOME}
CMD ["/usr/bin/zsh"]
