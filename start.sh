#!/usr/bin/env bash
echo "🚀 RunPod Worker Started"

# --- Mount volume
if [ -d "/runpod-volume" ]; then
  echo "🔗 Linking /runpod-volume → /workspace"
  rm -rf /workspace && ln -s /runpod-volume /workspace
fi

# --- Start ComfyUI
source /workspace/runpod-slim/ComfyUI/.venv/bin/activate
cd /workspace/runpod-slim/ComfyUI
echo "🧩 Starting ComfyUI on port 8188..."
python main.py --port 8188 --listen 0.0.0.0 --temp-directory /tmp > /workspace/comfyui.log 2>&1 &
deactivate

# --- Start handler
echo "⚙️ Launching RunPod handler..."
python3 -u /handler.py
