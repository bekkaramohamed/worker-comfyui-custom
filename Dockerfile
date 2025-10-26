# syntax=docker/dockerfile:1.4
# =======================================================
# 🧩 Base officielle ComfyUI Worker (sans modèles)
# =======================================================
FROM runpod/worker-comfyui:5.1.0-base

# =======================================================
# 📁 Préparation du workspace et du symlink
# =======================================================
RUN mkdir -p /workspace && \
    if [ -d "/runpod-volume/runpod-slim" ]; then \
        ln -s /runpod-volume/runpod-slim /workspace/runpod-slim && \
        echo "✅ Symlink /workspace/runpod-slim → /runpod-volume/runpod-slim created!"; \
    else \
        echo "ℹ️ /runpod-volume not detected (probably running on a Pod)."; \
    fi

WORKDIR /comfyui

# =======================================================
# ⚙️ Installation de Nunchaku
# =======================================================
RUN echo "📦 Installing Nunchaku..." && \
    pip install --no-cache-dir \
      "https://github.com/nunchaku-tech/nunchaku/releases/download/v1.0.0/nunchaku-1.0.0+torch2.6-cp312-cp312-linux_x86_64.whl"

# =======================================================
# 🧩 Installation des Custom Nodes via comfy-node-install
# =======================================================
# (méthode officielle RunPod pour ajouter des nodes)
RUN echo "🧩 Installing custom nodes via comfy-node-install..." && \
    comfy-node-install \
      rgthree-comfy \
      ComfyUI-Easy-Use \
      ComfyUI-TiledDiffusion \
      ComfyUI-nunchaku \
      ComfyUI-VideoHelperSuite \
      ComfyUI-WanVideoWrapper

# =======================================================
# ⚙️ Installation manuelle de quelques custom nodes non listés
# =======================================================
# Exemple : si certains ne sont pas dans le Comfy Registry
RUN echo "📦 Installing manual custom nodes..." && \
    mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes && \
    for repo in \
      "https://github.com/yolain/ComfyUI-Easy-Use.git" \
      "https://github.com/shiimizu/ComfyUI-TiledDiffusion.git" \
      "https://github.com/mit-han-lab/ComfyUI-nunchaku.git" \
      "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git" \
      "https://github.com/kijai/ComfyUI-WanVideoWrapper.git" \
      "https://github.com/rgthree/rgthree-comfy.git"; do \
      name=$(basename "$repo" .git); \
      if [ ! -d "$name" ]; then \
        git clone --depth 1 "$repo"; \
      fi; \
    done && \
    find . -type d -name ".git" -exec rm -rf {} + && \
    echo "📂 Installed custom nodes:" && ls -1 /comfyui/custom_nodes

# =======================================================
# 📦 Installation des requirements.txt des Custom Nodes
# =======================================================
RUN echo "📥 Installing dependencies for custom nodes..." && \
    for d in /comfyui/custom_nodes/*; do \
      if [ -f "$d/requirements.txt" ]; then \
        echo "➡️ Installing deps for $(basename $d)..." && \
        pip install --no-cache-dir -r "$d/requirements.txt" || true; \
      fi; \
    done && \
    echo "✅ All custom node dependencies installed."

# =======================================================
# 🧹 Nettoyage final
# =======================================================
RUN rm -rf /root/.cache /tmp/* /var/lib/apt/lists/*

# =======================================================
# 📦 (Optionnel) Copier des fichiers d’entrée statiques
# =======================================================
# Si tu veux fournir des images ou fichiers par défaut à ComfyUI :
# COPY input/ /comfyui/input/


