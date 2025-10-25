# =======================================================
# 🧱 Dockerfile - Custom Worker ComfyUI with Custom Nodes
# =======================================================

FROM runpod/worker-comfyui:5.5.0-base

WORKDIR /workspace/runpod-slim/ComfyUI

# =======================================================
# ⚙️ 1️⃣ Sécurisation minimale du build (git + venv check)
# =======================================================
RUN apt-get update -y && apt-get install -y git || true && \
    # Si la venv n'existe pas, on la crée proprement
    if [ ! -d "/workspace/runpod-slim/ComfyUI/.venv" ]; then \
        echo "⚙️ Creating new venv for ComfyUI..."; \
        python3 -m venv /workspace/runpod-slim/ComfyUI/.venv; \
    else \
        echo "✅ Existing venv detected, using it."; \
    fi && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install --upgrade pip

# =======================================================
# ⚙️ 2️⃣ Installation de UV + Upgrade PyTorch 2.9.0 (cu128)
# =======================================================
RUN /workspace/runpod-slim/ComfyUI/.venv/bin/pip install uv

RUN yes | /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip uninstall torch torchvision torchaudio triton && \
    rm -rf /root/.cache/uv /root/.cache/pip /root/.cache/torch_extensions /tmp/pip-* && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      torch==2.9.0+cu128 \
      torchvision==0.24.0+cu128 \
      torchaudio==2.9.0+cu128 \
      triton==3.5.0 \
      --extra-index-url https://download.pytorch.org/whl/cu128 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install numpy==1.26.4 sageattention && \
    rm -rf /workspace/runpod-slim/ComfyUI/.venv/lib/python3.12/site-packages/nunchaku* && \
    export TORCH_CUDA_ARCH_LIST="8.9" && \
    export FORCE_CMAKE=1 && \
    export MAX_JOBS=$(nproc) && \
    export USE_TORCH_VERSION=2.9.0 && \
    export UV_LINK_MODE=copy && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      git+https://github.com/nunchaku-tech/nunchaku.git@v1.0.0 \
      --no-binary nunchaku --reinstall --no-cache

# =======================================================
# 🧩 3️⃣ Installation des Custom Nodes requis
# =======================================================
WORKDIR /workspace/runpod-slim/ComfyUI/custom_nodes

RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/AlUlkesh/ComfyUI-TiledDiffusion.git && \
    git clone https://github.com/mit-han-lab/ComfyUI-nunchaku.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git

RUN for d in ComfyUI-* rgthree-comfy; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "Installing deps for $d..." && \
        /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install -r "$d/requirements.txt" || true; \
      fi; \
    done

# =======================================================
# ✅ 5️⃣ Final setup
# =======================================================
WORKDIR /workspace/runpod-slim/ComfyUI
ENV PYTHONPATH="/workspace/runpod-slim/ComfyUI:$PYTHONPATH"
ENV PATH="/workspace/runpod-slim/ComfyUI/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1
