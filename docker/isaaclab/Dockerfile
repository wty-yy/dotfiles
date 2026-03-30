ARG BASE_IMAGE=wtyyy/ubuntu:24.04
FROM ${BASE_IMAGE}

ARG DEFAULT_USER=user
ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ARG DEFAULT_HOME=/home/user
ARG PREPARED_HOME=/opt/isaaclab-home
ARG UV_ENV_NAME=isaaclab
ARG PYTHON_VERSION=3.11
ARG TORCH_VERSION=2.7.0
ARG TORCHVISION_VERSION=0.22.0
ARG ISAACLAB_VERSION=2.3.2.post1

ENV DEBIAN_FRONTEND=noninteractive
ENV UV_LINK_MODE=copy
ENV HOME=${DEFAULT_HOME}
ENV PATH=${DEFAULT_HOME}/.local/bin:${PATH}

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR ${PREPARED_HOME}

RUN set -eux; \
    install -d -m 0755 "${PREPARED_HOME}" "${DEFAULT_HOME}"; \
    uv venv "${UV_ENV_NAME}" --python "${PYTHON_VERSION}" --seed; \
    . "${UV_ENV_NAME}/bin/activate"; \
    uv pip install -U "torch==${TORCH_VERSION}" "torchvision==${TORCHVISION_VERSION}" --index-url https://download.pytorch.org/whl/cu128; \
    pip install --no-cache-dir "isaaclab[isaacsim,all]==${ISAACLAB_VERSION}" --extra-index-url https://pypi.nvidia.com; \
    rm -rf "${HOME}/.cache/pip" "${HOME}/.cache/uv"; \
    cp -a "${PREPARED_HOME}/." "${DEFAULT_HOME}/"; \
    chown -R "${DEFAULT_UID}:${DEFAULT_GID}" "${DEFAULT_HOME}"; \
    for entry in "${DEFAULT_HOME}/isaaclab" "${DEFAULT_HOME}/.local" "${DEFAULT_HOME}/.cache" "${DEFAULT_HOME}/.config"; do \
        if [ -e "${entry}" ]; then \
            chmod -R g+rwX "${entry}"; \
            find "${entry}" -type d -exec chmod g+s {} +; \
        fi; \
    done; \
    rm -rf "${PREPARED_HOME}"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libgomp1 libglu1; \
    apt-get update; \
    apt-get install -y --no-install-recommends mesa-utils vulkan-tools x11-apps; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    ACTIVATE_BLOCK_START="# >>> isaaclab auto-activate >>>"; \
    ACTIVATE_BLOCK_END="# <<< isaaclab auto-activate <<<"; \
    for zshrc in /root/.zshrc /etc/skel/.zshrc; do \
        if ! grep -Fq "${ACTIVATE_BLOCK_START}" "${zshrc}"; then \
            printf '\n%s\nif [ -f "%s/%s/bin/activate" ] && [ -z "${VIRTUAL_ENV:-}" ]; then\n  source "%s/%s/bin/activate"\nfi\n%s\n' \
                "${ACTIVATE_BLOCK_START}" "${DEFAULT_HOME}" "${UV_ENV_NAME}" "${DEFAULT_HOME}" "${UV_ENV_NAME}" "${ACTIVATE_BLOCK_END}" >> "${zshrc}"; \
        fi; \
    done

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER root
WORKDIR ${DEFAULT_HOME}
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/zsh"]
