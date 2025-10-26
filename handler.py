"""
Universal ComfyUI RunPod handler
- Works with multiple workflows (FluxMania, Infinite Talk, etc.)
- Supports dynamic overrides (prompt, denoise, steps, tile_batch, etc.)
- Handles input images/audio as base64
- Returns all generated images/videos in base64
"""

import runpod
import json
import os
import base64
import shutil
from pathlib import Path

# --- Global paths ---
WORKDIR = Path("/workspace/runpod-slim/ComfyUI")
WORKFLOW_DIR = WORKDIR / "workflows"
INPUT_DIR = WORKDIR / "input"
OUTPUT_DIR = WORKDIR / "output"
COMFY_PYTHON = WORKDIR / ".venv/bin/python"
COMFY_MAIN = WORKDIR / "main.py"


# ==========================================================
# Helpers
# ==========================================================

def load_workflow(name: str) -> dict:
    """Load a ComfyUI workflow JSON."""
    path = WORKFLOW_DIR / name
    if not path.exists():
        raise FileNotFoundError(f"Workflow {name} not found in {WORKFLOW_DIR}")
    with open(path, "r") as f:
        return json.load(f)


def save_temp_workflow(workflow: dict, suffix: str = "modified") -> Path:
    """Save modified workflow to a temp file."""
    tmp_path = Path(f"/tmp/workflow_{suffix}.json")
    with open(tmp_path, "w") as f:
        json.dump(workflow, f, indent=2)
    return tmp_path


def apply_overrides(workflow: dict, overrides: dict):
    """Apply input overrides dynamically on nodes."""
    for node in workflow.get("nodes", []):
        node_type = node.get("type")
        node_id = node.get("id")
        key_type = node_type
        key_full = f"{node_type}:{node_id}"

        for key in (key_full, key_type):
            if key not in overrides:
                continue
            changes = overrides[key]

            if isinstance(node.get("widgets_values"), list):
                for field, new_value in changes.items():
                    field = field.lower()
                    # basic field mapping
                    if field in ("prompt", "text"):
                        node["widgets_values"][0] = new_value
                    elif field in ("denoise",):
                        node["widgets_values"][-1] = new_value
                    elif field in ("steps",):
                        node["widgets_values"][2] = new_value
                    elif field in ("tile_batch", "tile_batch_size"):
                        node["widgets_values"][4] = new_value
                    elif field in ("audio", "image"):
                        # will be handled separately but we store names here
                        node["widgets_values"][0] = new_value
                    else:
                        for i, val in enumerate(node["widgets_values"]):
                            if isinstance(val, (float, int)):
                                node["widgets_values"][i] = new_value
                                break


def save_base64_files(items: list, subfolder: Path) -> list:
    """Save images or audio (base64) to input folder."""
    subfolder.mkdir(parents=True, exist_ok=True)
    saved_files = []
    for item in items:
        name = item["name"]
        data = item["data"]
        if data.startswith("data:"):
            data = data.split(",", 1)[-1]
        binary = base64.b64decode(data)
        path = subfolder / name
        with open(path, "wb") as f:
            f.write(binary)
        saved_files.append(str(path))
    return saved_files


def execute_comfyui(workflow_path: Path):
    """Run ComfyUI in headless mode."""
    cmd = f"{COMFY_PYTHON} {COMFY_MAIN} --workflow {workflow_path}"
    os.system(cmd)


def encode_outputs() -> list:
    """Encode all generated images/videos as base64."""
    results = []
    for ext in ("*.png", "*.jpg", "*.jpeg", "*.mp4", "*.webm"):
        for file in sorted(OUTPUT_DIR.glob(ext)):
            with open(file, "rb") as f:
                encoded = base64.b64encode(f.read()).decode("utf-8")
            file_type = "video" if file.suffix in [".mp4", ".webm"] else "image"
            results.append({
                "filename": file.name,
                "type": "base64",
                "data": encoded
            })
    return results


# ==========================================================
# Main handler
# ==========================================================

def handler(job):
    """RunPod Serverless handler for ComfyUI workflows."""
    job_input = job.get("input", {})

    # 1️⃣ Load workflow
    workflow_name = job_input.get("workflow", "fluxmania_txt2img_upscale.json")
    workflow = load_workflow(workflow_name)

    # 2️⃣ Apply overrides
    overrides = job_input.get("overrides", {})
    if overrides:
        apply_overrides(workflow, overrides)

    tmp_workflow = save_temp_workflow(workflow)

    # 3️⃣ Save input files (images, audio)
    if "images" in job_input:
        save_base64_files(job_input["images"], INPUT_DIR)
    if "audio" in job_input:
        save_base64_files(job_input["audio"], INPUT_DIR)

    # 4️⃣ Run ComfyUI
    execute_comfyui(tmp_workflow)

    # 5️⃣ Encode outputs (images + videos)
    output_files = encode_outputs()

    # 6️⃣ Clean output directory
    shutil.rmtree(OUTPUT_DIR)
    OUTPUT_DIR.mkdir(exist_ok=True)

    # 7️⃣ Return API-compliant payload
    return {
