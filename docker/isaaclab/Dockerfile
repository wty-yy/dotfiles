ARG BASE_IMAGE=wtyyy/ubuntu:24.04
FROM ${BASE_IMAGE}

ARG INITIAL_USER=init-user
ARG DEFAULT_USER=user
ARG DEFAULT_HOME=/home/user
ARG UV_ENV_NAME=isaaclab
ARG PYTHON_VERSION=3.11
ARG TORCH_VERSION=2.7.0
ARG TORCHVISION_VERSION=0.22.0
ARG ISAACLAB_VERSION=2.3.2.post1

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=${DEFAULT_HOME}
ENV PATH=${DEFAULT_HOME}/${UV_ENV_NAME}/bin:${DEFAULT_HOME}/.local/bin:${PATH}

# Install runtime dependencies for isaaclab
USER root
RUN set -eux; \
    sudo apt-get update; \
    sudo apt-get install -y --no-install-recommends libgomp1 libglu1 mesa-utils vulkan-tools x11-apps; \
    sudo apt-get clean; \
    sudo rm -rf /var/lib/apt/lists/*

# Install python env & pkg by INITIAL_USER, then switch to DEFAULT_USER
USER ${INITIAL_USER}
WORKDIR ${DEFAULT_HOME}

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh; \
    rm -rf "${DEFAULT_HOME}/.config"

# Create uv env, install torch and isaaclab
RUN set -eux; \
    uv venv "${UV_ENV_NAME}" --python "${PYTHON_VERSION}" --seed; \
    . "${UV_ENV_NAME}/bin/activate"; \
    uv pip install --no-cache-dir "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" --index-url https://download.pytorch.org/whl/cu128; \
    uv pip install --no-cache-dir "isaaclab[isaacsim,all]==${ISAACLAB_VERSION}" --extra-index-url https://pypi.nvidia.com; \
    rm -rf "${DEFAULT_HOME}/.cache"; \
    chmod -R g+rwX "${DEFAULT_HOME}/${UV_ENV_NAME}" "${DEFAULT_HOME}/.local"

RUN set -eux; \
    ACTIVATE_BLOCK_START="# >>> isaaclab auto-activate >>>"; \
    ACTIVATE_BLOCK_END="# <<< isaaclab auto-activate <<<"; \
    if ! grep -Fq "${ACTIVATE_BLOCK_START}" "${DEFAULT_HOME}/.zshrc"; then \
        printf '\n%s\nif [ -f "%s/%s/bin/activate" ] && [ -z "${VIRTUAL_ENV:-}" ]; then\n  source "%s/%s/bin/activate"\nfi\n%s\n' \
            "${ACTIVATE_BLOCK_START}" "${DEFAULT_HOME}" "${UV_ENV_NAME}" "${DEFAULT_HOME}" "${UV_ENV_NAME}" "${ACTIVATE_BLOCK_END}" >> "${DEFAULT_HOME}/.zshrc"; \
    fi

USER ${DEFAULT_USER}
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/zsh"]
