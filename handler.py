import requests
import time
import json
import base64

COMFY_URL = "http://127.0.0.1:8188"

def comfy_run(workflow_json):
    # 1️⃣ Envoi du workflow à ComfyUI
    res = requests.post(f"{COMFY_URL}/prompt", json={"prompt": workflow_json})
    res.raise_for_status()
    prompt_id = res.json()["prompt_id"]
    print(f"✅ Workflow envoyé avec ID: {prompt_id}")

    # 2️⃣ Attente de la fin du job
    while True:
        history = requests.get(f"{COMFY_URL}/history/{prompt_id}").json()
        if prompt_id in history:
            data = history[prompt_id]
            if data.get("status") == "completed" or data.get("outputs"):
                print("✅ Job terminé.")
                return data["outputs"]
        time.sleep(1)

# Exemple d'appel
if __name__ == "__main__":
    with open("workflow_api.json") as f:
        workflow = json.load(f)

    result = comfy_run(workflow)
    print(json.dumps(result, indent=2))
