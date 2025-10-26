# syntax=docker/dockerfile:1.4
FROM runpod/worker-comfyui:5.1.0-base

# =======================================================
# ⚙️ Dépendances système
# =======================================================
RUN apt-get update && apt-get install -y --no-install-recommends git curl && rm -rf /var/lib/apt/lists/*

# =======================================================
# 🔍 Torch + CUDA Check
# =======================================================
RUN echo "🧠 Checking Torch and CUDA version..." && \
    python3 -c "import torch; print(f'Torch version: {torch.__version__}, CUDA: {torch.version.cuda}')"

# =======================================================
# ⚙️ Installation de Nunchaku
# =======================================================
RUN echo "📦 Installing Nunchaku wheel..." && \
    pip install --no-cache-dir \
      'https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.0/nunchaku-1.0.0+torch2.6-cp312-cp312-linux_x86_64.whl'

# =======================================================
# 🧩 Installation des nodes depuis le registry
# =======================================================
RUN echo "🧩 Installing registry-based custom nodes..." && \
    comfy-node-install \
      rgthree-comfy \
      ComfyUI-nunchaku \
      ComfyUI-WanVideoWrapper || true

# =======================================================
# 🧠 Clonage manuel des nodes non présents dans le registry
# =======================================================
RUN echo "📦 Cloning manual custom nodes..." && \
    cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone --depth 1 https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    git clone --depth 1 https://github.com/shiimizu/ComfyUI-TiledDiffusion.git && \
    rm -rf /comfyui/custom_nodes/*/.git && \
    echo "📥 Installing deps for manually cloned nodes..." && \
    for d in /comfyui/custom_nodes/*; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "📦 Installing deps for $d..." && pip install -r "$d/requirements.txt" || true; \
      fi; \
    done

# =======================================================
# 💾 Téléchargement des modèles Hugging Face
# =======================================================
ENV HF_TOKEN="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"

RUN echo "🧠 Downloading base models from Hugging Face..." && \
    mkdir -p /comfyui/models/{diffusion_models,clip,vae,upscale_models,loras,clip_vision,wav2vec2} && \
    set -eux; \
    # --- FLUX DiT Loader (FP4)
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/diffusion_models/svdq-fp4_r32-fluxmania-legacy.safetensors \
      https://huggingface.co/spooknik/Fluxmania-SVDQ/resolve/main/svdq-fp4_r32-fluxmania-legacy.safetensors && \
    # --- FLUX DiT Loader (INT7)
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/diffusion_models/svdq-int4_r32-fluxmania-legacy.safetensors \
      https://huggingface.co/spooknik/Fluxmania-SVDQ/resolve/main/svdq-int4_r32-fluxmania-legacy.safetensors?download=true && \
    # --- Text Encoder Loader V2
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/clip/clip_l.safetensors \
      https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors && \
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/clip/t5xxl_fp8_e4m3fn_scaled.safetensors \
      https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn_scaled.safetensors && \
    # --- VAE
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/vae/ae.safetensors \
      https://huggingface.co/Comfy-Org/Lumina_Image_2.0_Repackaged/resolve/main/split_files/vae/ae.safetensors && \
    # --- Upscale Model
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/upscale_models/4xNomos2_hq_dat2.safetensors \
      https://huggingface.co/Phips/4xNomos2_hq_dat2/resolve/main/4xNomos2_hq_dat2.safetensors && \
    # --- Flux Kontext diffusion model
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors \
      https://huggingface.co/Comfy-Org/flux1-kontext-dev_ComfyUI/resolve/main/split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors && \
    # --- WanVideo VAE
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/vae/wan_2.1_vae.safetensors \
      https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors && \
    # --- WanVideo CLIP Vision
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/clip/clip_vision_h.safetensors \
      https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors && \
    # --- Text Encoder UMT5
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/clip/umt5-xxl-enc-bf16.safetensors \
      https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors && \
    # --- Wav2Vec2 audio model
    curl -L -H "Authorization: Bearer ${HF_TOKEN}" -o /comfyui/models/wav2vec2/wav2vec2-chinese-base_fp16.safetensors \
      https://huggingface.co/Kijai/wav2vec2_safetensors/resolve/main/wav2vec2-chinese-base_fp16.safetensors?download=true

# =======================================================
# ✅ Vérifications
# =======================================================
RUN echo "✅ Installed custom nodes:" && ls -1 /comfyui/custom_nodes && \
    echo "✅ Installed model folders:" && ls -1 /comfyui/models && \
    du -sh /comfyui/models/* || true
