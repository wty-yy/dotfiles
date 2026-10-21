ARG BASE_IMAGE=wtyyy/ubuntu:24.04
FROM ${BASE_IMAGE}

ARG INITIAL_USER=init-user
ARG DEFAULT_USER=user
ARG DEFAULT_HOME=/home/user
ARG UV_ENV_NAME=isaaclab
ARG PYTHON_VERSION=3.12
ARG TORCH_VERSION=2.11.0
ARG TORCHVISION_VERSION=0.26.0
ARG PYTORCH_CUDA=cu128
ARG UV_PRERELEASE=if-necessary
# Isaac Lab 3.0 release uses this PEP 440 package version.
ARG ISAACLAB_VERSION=3.0.0
# Optional uv overrides published by the matching Isaac Lab release.
ARG UV_OVERRIDES_URL=

ENV HOME=${DEFAULT_HOME}
ENV PATH=${DEFAULT_HOME}/${UV_ENV_NAME}/bin:${DEFAULT_HOME}/.local/bin:${PATH}

# Install runtime dependencies for isaaclab
USER root
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libgomp1 libglu1 mesa-utils vulkan-tools x11-apps; \
    rm -rf /var/lib/apt/lists/*

# Install python env & pkg by INITIAL_USER, then switch to DEFAULT_USER
USER ${INITIAL_USER}
WORKDIR ${DEFAULT_HOME}

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh

# Restore Isaac Sim 6.2 runtime pins that the published uv overrides relax.
COPY --chown=${INITIAL_UID}:${INITIAL_GID} uv-constraints.txt /tmp/uv-constraints.txt

# Create uv env and install IsaacLab with its target PyTorch backend.
# Isaac Sim's published metadata can request a different default PyTorch wheel.
# Keep the versions selected by versions.json instead, and append the uv
# overrides published by the matching Isaac Lab release when provided.
# Constraints keep transitive runtime packages compatible with Isaac Sim.
RUN set -eux; \
    uv venv "${UV_ENV_NAME}" --python "${PYTHON_VERSION}" --seed; \
    . "${UV_ENV_NAME}/bin/activate"; \
    OVERRIDE_FILE="$(mktemp)"; \
    printf 'torch==%s\ntorchvision==%s\ntorchaudio==%s\n' \
        "${TORCH_VERSION}" "${TORCHVISION_VERSION}" "${TORCH_VERSION}" > "${OVERRIDE_FILE}"; \
    if [ -n "${UV_OVERRIDES_URL}" ]; then \
        curl -fsSL "${UV_OVERRIDES_URL}" >> "${OVERRIDE_FILE}"; \
    fi; \
    uv pip install --no-cache-dir \
        --torch-backend "${PYTORCH_CUDA}" \
        --overrides "${OVERRIDE_FILE}" \
        --constraints /tmp/uv-constraints.txt \
        --prerelease="${UV_PRERELEASE}" \
        --index-strategy unsafe-best-match \
        "isaaclab[isaacsim,all]==${ISAACLAB_VERSION}" \
        --extra-index-url https://pypi.nvidia.com; \
    "${UV_ENV_NAME}/bin/python" -c 'import numpy, numba; assert numpy.__version__ == "2.3.1", numpy.__version__'; \
    rm -f "${OVERRIDE_FILE}" /tmp/uv-constraints.txt; \
    rm -rf "${DEFAULT_HOME}/.cache"; \
    chmod -R g+rwX "${DEFAULT_HOME}/${UV_ENV_NAME}" "${DEFAULT_HOME}/.local"

RUN printf '%s\n' \
    '' \
    '# >>> isaaclab auto-activate >>>' \
    "if [ -f \"${DEFAULT_HOME}/${UV_ENV_NAME}/bin/activate\" ] && [ -z \"\${VIRTUAL_ENV:-}\" ]; then" \
    "  source \"${DEFAULT_HOME}/${UV_ENV_NAME}/bin/activate\"" \
    'fi' \
    '# <<< isaaclab auto-activate <<<' >> "${DEFAULT_HOME}/.zshrc"

USER ${DEFAULT_USER}
