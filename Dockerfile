# =======================================================
# 🧱 Dockerfile - Custom Worker ComfyUI with Custom Nodes
# =======================================================

FROM runpod/worker-comfyui:5.5.0-base

WORKDIR /workspace/runpod-slim/ComfyUI


# =======================================================
# ⚙️ 2️⃣ CUDA + PyTorch 2.9.0 (cu128)
# =======================================================
# =======================================================
# ⚙️ 2️⃣ PyTorch 2.9.0 (cu128) + nettoyage cache
# =======================================================
RUN apt update && apt install -y git && \
    yes | /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip uninstall torch torchvision torchaudio triton && \
    rm -rf /root/.cache/uv /root/.cache/pip /root/.cache/torch_extensions /tmp/pip-* && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      torch==2.9.0+cu128 \
      torchvision==0.24.0+cu128 \
      torchaudio==2.9.0+cu128 \
      triton==3.5.0 \
      --extra-index-url https://download.pytorch.org/whl/cu128 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install numpy==1.26.4 && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install sageattention && \
    rm -rf /workspace/runpod-slim/ComfyUI/.venv/lib/python3.12/site-packages/nunchaku* && \
    export TORCH_CUDA_ARCH_LIST="8.9" && \
    export FORCE_CMAKE=1 && \
    export MAX_JOBS=$(nproc) && \
    export USE_TORCH_VERSION=2.9.0 && \
    export UV_LINK_MODE=copy && \
    /workspace/runpod-slim/ComfyUI/.venv/bin/python -m uv pip install \
      git+https://github.com/nunchaku-tech/nunchaku.git@v1.0.0 \
      --no-binary nunchaku \
      --reinstall \
      --no-cache


# =======================================================
# 🧩 3️⃣ Installation des Custom Nodes requis
# =======================================================
WORKDIR /workspace/runpod-slim/ComfyUI/custom_nodes

# Clone des dépôts
RUN git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/AlUlkesh/ComfyUI-TiledDiffusion.git && \
    git clone https://github.com/mit-han-lab/ComfyUI-nunchaku.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git

# =======================================================
# 📦 4️⃣ Installation des requirements de chaque node
# =======================================================
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
