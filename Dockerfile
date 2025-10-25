# syntax=docker/dockerfile:1.4

FROM runpod/comfyui:latest
WORKDIR /workspace/runpod-slim/ComfyUI

# =======================================================
# ⚙️ 1️⃣ Git + venv + pip upgrade
# =======================================================
RUN set -e && \
    apt-get update -y && apt-get install -y git python3-venv && \
    if [ ! -d "/workspace/runpod-slim/ComfyUI/.venv" ]; then \
        echo "⚙️ Creating new venv for ComfyUI..."; \
        python3 -m venv /workspace/runpod-slim/ComfyUI/.venv; \
    else \
        echo "✅ Existing venv detected, using it."; \
    fi && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install --upgrade pip && \
    rm -rf /var/lib/apt/lists/*

# =======================================================
# 🔍 GPU Check (log only)
# =======================================================
RUN if command -v nvidia-smi >/dev/null 2>&1 || [ -e "/dev/nvidia0" ]; then \
        echo "✅ GPU détecté"; \
    else \
        echo "⚠️ Aucun GPU détecté, fallback CPU"; \
    fi

# =======================================================
# ⚙️ 2️⃣ Installation de uv et check Torch version
# =======================================================
RUN /workspace/runpod-slim/ComfyUI/.venv/bin/pip install uv && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -c "import torch; print(f'Torch version: {torch.__version__}, CUDA: {torch.version.cuda}')"

# =======================================================
# ⚙️ 3️⃣ Installation de Nunchaku (wheel Torch 2.6)
# =======================================================
RUN /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
    'https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.1/nunchaku-1.0.1+torch2.6-cp312-cp312-linux_x86_64.whl' \
    --no-cache-dir

# =======================================================
# 🧩 4️⃣ Installation des Custom Nodes
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
