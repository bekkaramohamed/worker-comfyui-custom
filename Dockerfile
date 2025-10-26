# syntax=docker/dockerfile:1.4
FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

# =======================================================
# 📁 Préparation du workspace
# =======================================================
RUN mkdir -p /workspace && \
    if [ -d "/runpod-volume/runpod-slim" ]; then \
        ln -s /runpod-volume/runpod-slim /workspace/runpod-slim && \
        echo "✅ Symlink /workspace/runpod-slim → /runpod-volume/runpod-slim created!"; \
    else \
        echo "ℹ️ /runpod-volume not detected (probably running on a Pod)."; \
    fi
WORKDIR /workspace/runpod-slim/ComfyUI

# =======================================================
# 🧩 Installation de base (Git, Curl, Certs)
# =======================================================
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update -y && \
    apt-get install -y --no-install-recommends git curl ca-certificates && \
    update-ca-certificates && \
    echo "✅ Base system ready with Python 3.12" && \
    python3 --version && pip --version

# =======================================================
# ⚙️ Création du venv + mise à jour pip
# =======================================================
RUN echo "🧹 Removing any existing virtual environment..." && \
    rm -rf /workspace/runpod-slim/ComfyUI/.venv && \
    echo "⚙️ Creating new venv for ComfyUI (Python 3.12)..." && \
    python3.12 -m venv /workspace/runpod-slim/ComfyUI/.venv && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install --upgrade pip

# =======================================================
# 🔍 GPU Check
# =======================================================
RUN if command -v nvidia-smi >/dev/null 2>&1 || [ -e "/dev/nvidia0" ]; then \
        echo "✅ GPU detected"; \
    else \
        echo "⚠️ No GPU detected, fallback CPU"; \
    fi

# =======================================================
# ⚙️ Installation de uv (gestionnaire rapide de deps)
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install uv

# =======================================================
# ⚙️ Torch 2.6.0 (CUDA 12.4) + dépendances
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      torch==2.6.0 \
      torchvision==0.21.0 \
      torchaudio==2.6.0 \
      --index-url https://download.pytorch.org/whl/cu124 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install numpy==1.26.4 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install sageattention && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -c "import torch; print(f'Torch: {torch.__version__}, CUDA: {torch.version.cuda}')"

# =======================================================
# ⚙️ Installation de Nunchaku
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
    "https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.0/nunchaku-1.0.0+torch2.6-cp312-cp312-linux_x86_64.whl" \
    --no-cache-dir

# =======================================================
# 🧹 Clonage et nettoyage des Custom Nodes
# =======================================================
RUN echo "🧹 Vérification du dossier custom_nodes..." && \
    rm -rf custom_nodes && mkdir -p custom_nodes && \
    echo "📦 Clonage des Custom Nodes..." && \
    git -C custom_nodes clone --depth 1 https://github.com/octocat/Hello-World.git && \
    git -C custom_nodes clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git -C custom_nodes clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git -C custom_nodes clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git -C custom_nodes clone --depth 1 https://github.com/shiimizu/ComfyUI-TiledDiffusion.git && \
    git -C custom_nodes clone --depth 1 https://github.com/mit-han-lab/ComfyUI-nunchaku.git && \
    git -C custom_nodes clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && \
    find custom_nodes -type d -name ".git" -exec rm -rf {} + && \
    echo "📂 Contenu final :" && ls -1 custom_nodes

# =======================================================
# ⚙️ Installation requirements des nodes (sans deps dupliquées)
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    for d in custom_nodes/*; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "Installing deps for $d…" && \
        /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install --no-deps -r "$d/requirements.txt" || true; \
      fi; \
    done

# =======================================================
# ✅ Final setup
# =======================================================
WORKDIR /workspace/runpod-slim/ComfyUI
ENV PYTHONPATH="/workspace/runpod-slim/ComfyUI:$PYTHONPATH"
ENV PATH="/workspace/runpod-slim/ComfyUI/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1

# =======================================================
# 🧹 Nettoyage final
# =======================================================
RUN rm -rf /root/.cache /var/lib/apt/lists/* /tmp/* custom_nodes/**/.git

# =======================================================
# 🚀 Entrypoint
# =======================================================
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/bin/bash", "/start.sh"]
