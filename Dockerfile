# syntax=docker/dockerfile:1.4

FROM runpod/comfyui:latest
WORKDIR /workspace/runpod-slim/ComfyUI

# =======================================================
# ⚙️ 1️⃣ Git + venv + pip upgrade
# =======================================================
RUN set -e && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends git ca-certificates python3-venv curl && \
    update-ca-certificates && \
    echo "🌐 Testing internet connectivity..." && \
    if curl -Is https://github.com >/dev/null 2>&1; then \
        echo "✅ Internet access confirmed."; \
    else \
        echo "❌ No internet access (cannot reach https://github.com)"; \
        exit 1; \
    fi && \
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
RUN /workspace/runpod-slim/ComfyUI/.venv/bin/pip install uv


# =======================================================
# ⚙️ 2️⃣ Installation de Torch 2.6.0 (CUDA 12.4) + dépendances
# =======================================================
RUN /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      torch==2.6.0 \
      torchvision==0.21.0 \
      torchaudio==2.6.0 \
      --index-url https://download.pytorch.org/whl/cu124 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install numpy==1.26.4 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/pip install sageattention && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -c "import torch; print(f'Torch version: {torch.__version__}, CUDA: {torch.version.cuda}')" && \
    rm -rf /root/.cache/uv /root/.cache/pip /root/.cache/torch_extensions /tmp/pip-*



# =======================================================
# ⚙️ 3️⃣ Installation de Nunchaku v1.0.0 (Torch 2.6, Python 3.12)
# =======================================================
RUN /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
    "https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.0/nunchaku-1.0.0+torch2.6-cp312-cp312-linux_x86_64.whl" \
    --no-cache-dir

# =======================================================
# 🧩 4️⃣ Installation des Custom Nodes
# =======================================================
WORKDIR /workspace/runpod-slim/ComfyUI/custom_nodes

RUN set -e && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends git ca-certificates curl && \
    update-ca-certificates && \
    echo "🌐 Vérification Git + accès GitHub..." && \
    git --version && \
    curl -Is https://github.com >/dev/null 2>&1 && echo "✅ GitHub accessible." && \
    export GIT_TERMINAL_PROMPT=0 && \
    echo "🧪 Test clone public avec octocat/Hello-World..." && \
    git clone --depth 1 https://github.com/octocat/Hello-World.git && \
    echo "✅ Test clone réussi, poursuite des installations..." && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-WanVideoWrapper.git && sleep 3 && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && sleep 3 && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && sleep 3 && \
    git clone --depth 1 https://github.com/AlUlkesh/ComfyUI-TiledDiffusion.git && sleep 3 && \
    git clone --depth 1 https://github.com/mit-han-lab/ComfyUI-nunchaku.git && sleep 3 && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && sleep 3 && \
    echo "📂 Contenu du dossier : " && ls -1 && \
    rm -rf /var/lib/apt/lists/*

RUN for d in *; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "Installing deps for $d…" && \
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
