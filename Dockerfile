# syntax=docker/dockerfile:1.4
FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /workspace && \
    if [ -d "/runpod-volume/runpod-slim" ]; then \
        ln -s /runpod-volume/runpod-slim /workspace/runpod-slim && \
        echo "✅ Symlink /workspace/runpod-slim → /runpod-volume/runpod-slim created :!"; \
    else \
        echo "ℹ️ /runpod-volume not detected (probably running on a Pod)."; \
    fi
WORKDIR /workspace/runpod-slim/ComfyUI

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git curl ca-certificates && \
    update-ca-certificates && \
    echo "✅ Python 3.12 + Debian slim ready" && \
    python3 --version && pip --version


# =======================================================
# ⚙️ 1️⃣ Git + venv + pip upgrade
# =======================================================
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git ca-certificates curl && \
    update-ca-certificates && \
    echo "🌐 Testing internet connectivity..." && \
    if curl -Is https://github.com >/dev/null 2>&1; then \
        echo "✅ Internet access confirmed."; \
    else \
        echo "❌ No internet access (cannot reach https://github.com)"; \
        exit 1; \
    fi && \
    echo "🧹 Removing any existing virtual environment..." && \
    rm -rf /workspace/runpod-slim/ComfyUI/.venv && \
    echo "⚙️ Creating new venv for ComfyUI (Python 3.12)..." && \
    python3.12 -m venv /workspace/runpod-slim/ComfyUI/.venv && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python --version && \
    echo "⬆️ Upgrading pip..." && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install --upgrade pip




# =======================================================
# 🔍 GPU Check (log only)
# =======================================================
RUN if command -v nvidia-smi >/dev/null 2>&1 || [ -e "/dev/nvidia0" ]; then \
        echo "✅ GPU détecté"; \
    else \
        echo "⚠️ Aucun GPU détecté, fallback CPU"; \
    fi


# =======================================================
# ⚙️ 2️⃣ Installation de uv
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install uv


# =======================================================
# ⚙️ 3️⃣ Installation de Torch 2.6.0 (CUDA 12.4) + dépendances
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      torch==2.6.0 \
      torchvision==0.21.0 \
      torchaudio==2.6.0 \
      --index-url https://download.pytorch.org/whl/cu124 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install numpy==1.26.4 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install sageattention && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -c "import torch; print(f'Torch version: {torch.__version__}, CUDA: {torch.version.cuda}')"


# =======================================================
# ⚙️ 4️⃣ Installation de Nunchaku
# =======================================================
RUN --mount=type=cache,target=/root/.cache \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
    "https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.0/nunchaku-1.0.0+torch2.6-cp312-cp312-linux_x86_64.whl" \
    --no-cache-dir


# =======================================================
# 🧩 5️⃣ Installation des Custom Nodes
# =======================================================

WORKDIR /workspace/runpod-slim/ComfyUI

RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update -y && \
    apt-get install -y --no-install-recommends git ca-certificates curl && \
    update-ca-certificates && \
    echo "🌐 Vérification Git + accès GitHub..." && \
    git --version && \
    curl -Is https://github.com >/dev/null 2>&1 && echo "✅ GitHub accessible." && \
    export GIT_TERMINAL_PROMPT=0 && \
    echo "🧹 Suppression de l'ancien dossier custom_nodes..." && \
    rm -rf custom_nodes && mkdir -p custom_nodes && cd custom_nodes && \
    echo "📦 Clonage des Custom Nodes..." && \
    git clone --depth 1 https://github.com/octocat/Hello-World.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth 1 https://github.com/shiimizu/ComfyUI-TiledDiffusion.git && \
    git clone --depth 1 https://github.com/mit-han-lab/ComfyUI-nunchaku.git && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && \
    echo "📂 Contenu final du dossier custom_nodes :" && ls -1 custom_nodes

RUN --mount=type=cache,target=/root/.cache \
    for d in *; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "Installing deps for $d…" && \
        /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install -r "$d/requirements.txt" || true; \
      fi; \
    done


# =======================================================
# ✅ 6️⃣ Final setup
# =======================================================
WORKDIR /workspace/runpod-slim/ComfyUI
ENV PYTHONPATH="/workspace/runpod-slim/ComfyUI:$PYTHONPATH"
ENV PATH="/workspace/runpod-slim/ComfyUI/.venv/bin:$PATH"
ENV PYTHONUNBUFFERED=1

# =======================================================
# 🚀 7️⃣ Démarrage automatique de ComfyUI
# =======================================================
RUN rm -rf /var/lib/apt/lists/* /root/.cache

COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/bin/bash", "/start.sh"]

