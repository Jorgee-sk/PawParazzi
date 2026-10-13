"""Se ejecuta al construir la imagen: descarga el modelo y convierte las frases en vectores.

Deja en /app/model (lo único que pasa a la imagen final):
  - vision_model.onnx     (lo único que se usa al atender peticiones)
  - text_embeddings.npz   (un vector normalizado por frase)
El modelo de texto y el tokenizador solo hacen falta aquí y no se quedan en la imagen final.
"""
import hashlib
import os
import sys
import urllib.request

import numpy as np
import onnxruntime as ort
from tokenizers import Tokenizer


BASE = "https://huggingface.co/{}/resolve/{}".format(
    os.environ.get("MODEL_REPO", ""), os.environ.get("MODEL_REVISION", ""))
OUT = "/app/model"
TMP = "/tmp/model-build"


def download(path: str, target: str) -> None:
    os.makedirs(os.path.dirname(target), exist_ok=True)
    print(f"descargando {path} ...", flush=True)
    urllib.request.urlretrieve(f"{BASE}/{path}", target)
    digest = hashlib.sha256(open(target, "rb").read()).hexdigest()
    print(f"  {os.path.getsize(target) / 1e6:.1f} MB  sha256={digest}", flush=True)


def fetch() -> None:
    download("onnx/vision_model.onnx", f"{OUT}/vision_model.onnx")
    download("onnx/text_model.onnx", f"{TMP}/text_model.onnx")
    download("tokenizer.json", f"{TMP}/tokenizer.json")


def main() -> None:
    from prompts import GROUPS

    tokenizer = Tokenizer.from_file(f"{TMP}/tokenizer.json")
    tokenizer.no_padding()
    session = ort.InferenceSession(f"{TMP}/text_model.onnx", providers=["CPUExecutionProvider"])
    input_names = {i.name for i in session.get_inputs()}
    output_names = [o.name for o in session.get_outputs()]
    if "text_embeds" not in output_names:
        sys.exit(f"El modelo de texto no expone text_embeds: {output_names}")

    def embed(sentence: str) -> np.ndarray:
        # Una frase por llamada y sin relleno: así no depende de cómo se rellenen las secuencias.
        ids = np.array([tokenizer.encode(sentence).ids], dtype=np.int64)
        feeds = {"input_ids": ids}
        if "attention_mask" in input_names:
            feeds["attention_mask"] = np.ones_like(ids)
        vector = session.run(["text_embeds"], feeds)[0][0]
        return vector / np.linalg.norm(vector)

    arrays = {}
    for group, (positive, neutral) in GROUPS.items():
        arrays[f"{group}_positive"] = np.stack([embed(s) for s in positive]).astype(np.float32)
        arrays[f"{group}_neutral"] = np.stack([embed(s) for s in neutral]).astype(np.float32)
        print(f"{group}: {len(positive)} frases positivas, {len(neutral)} neutras", flush=True)
    np.savez(f"{OUT}/text_embeddings.npz", **arrays)

    vision = ort.InferenceSession(f"{OUT}/vision_model.onnx", providers=["CPUExecutionProvider"])
    outputs = [o.name for o in vision.get_outputs()]
    if "image_embeds" not in outputs:
        sys.exit(f"El modelo de visión no expone image_embeds: {outputs}")
    print("modelo de visión:", [(i.name, i.shape) for i in vision.get_inputs()], outputs, flush=True)


if __name__ == "__main__":
    # "fetch" descarga el modelo; "embed" calcula los vectores. Van en pasos distintos del
    # Containerfile para que cambiar prompts.py no vuelva a descargar el modelo.
    {"fetch": fetch, "embed": main}[sys.argv[1]]()
