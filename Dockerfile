# syntax=docker/dockerfile:1.4
FROM runpod/worker-comfyui:5.1.0-base

RUN apt-get update && apt-get install -y --no-install-recommends git && rm -rf /var/lib/apt/lists/*

RUN echo "🧠 Checking Torch and CUDA version before Nunchaku install..." && \
    python3 -c "import torch; print(f'Torch version: {torch.__version__}, CUDA: {torch.version.cuda}')"

RUN echo "📦 Installing Nunchaku wheel..." && \
    pip install --no-cache-dir \
      'https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.0/nunchaku-1.0.0+torch2.6-cp312-cp312-linux_x86_64.whl'

RUN echo "🧩 Installing registry-based custom nodes..." && \
    comfy-node-install \
      rgthree-comfy \
      ComfyUI-Easy-Use \
      ComfyUI-nunchaku \
      ComfyUI-VideoHelperSuite \
      ComfyUI-WanVideoWrapper || true

# --- Seul celui-ci est cloné manuellement
RUN echo "📦 Cloning ComfyUI-TiledDiffusion..." && \
    cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/shiimizu/ComfyUI-TiledDiffusion.git && \
    rm -rf /comfyui/custom_nodes/ComfyUI-TiledDiffusion/.git && \
    echo "📥 Installing deps for ComfyUI-TiledDiffusion..." && \
    pip install -r /comfyui/custom_nodes/ComfyUI-TiledDiffusion/requirements.txt || true

RUN echo "✅ Installed custom nodes:" && ls -1 /comfyui/custom_nodes
