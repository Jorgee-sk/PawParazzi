"""Servicio de revisión de fotos de PawParazzi.

POST /classify  (cuerpo: bytes de una imagen JPEG o PNG)
  -> {"animal": 0.97, "violence": 0.01, "sexual": 0.00, "model": "...", "millis": 85}

Cada valor es una puntuación entre 0 y 1. Este servicio solo puntúa: la decisión de aceptar o
rechazar (umbrales y política) la toma el backend. Las imágenes se procesan en memoria y no se
guardan ni se registran.
"""
import io
import os
import time

import numpy as np
import onnxruntime as ort
from fastapi import FastAPI, HTTPException, Request
from PIL import Image

MODEL_DIR = os.environ.get("MODEL_DIR", "/app/model")
MODEL_NAME = os.environ.get("MODEL_NAME", "clip-vit-base-patch32")
MAX_BYTES = int(os.environ.get("MAX_BYTES", str(12 * 1024 * 1024)))
THREADS = int(os.environ.get("MODEL_THREADS", "2"))

# Preprocesado estándar de CLIP.
SIZE = 224
MEAN = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
STD = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)
LOGIT_SCALE = 100.0
GROUPS = ("animal", "violence", "sexual")

options = ort.SessionOptions()
options.intra_op_num_threads = THREADS
session = ort.InferenceSession(f"{MODEL_DIR}/vision_model.onnx", options, providers=["CPUExecutionProvider"])
INPUT_NAME = session.get_inputs()[0].name
embeddings = np.load(f"{MODEL_DIR}/text_embeddings.npz")

app = FastAPI(title="PawParazzi · revisión de fotos", docs_url=None, redoc_url=None)


def preprocess(data: bytes) -> np.ndarray:
    image = Image.open(io.BytesIO(data))
    image.load()
    image = image.convert("RGB")
    width, height = image.size
    scale = SIZE / min(width, height)
    image = image.resize((max(SIZE, round(width * scale)), max(SIZE, round(height * scale))), Image.BICUBIC)
    left = (image.width - SIZE) // 2
    top = (image.height - SIZE) // 2
    image = image.crop((left, top, left + SIZE, top + SIZE))
    pixels = (np.asarray(image, dtype=np.float32) / 255.0 - MEAN) / STD
    return pixels.transpose(2, 0, 1)[None]


def score(image_vector: np.ndarray, group: str) -> float:
    """Parte de la probabilidad que se llevan las frases positivas frente a las neutras."""
    positive = embeddings[f"{group}_positive"]
    neutral = embeddings[f"{group}_neutral"]
    logits = LOGIT_SCALE * np.concatenate([positive, neutral]) @ image_vector
    logits -= logits.max()
    probabilities = np.exp(logits) / np.exp(logits).sum()
    return float(probabilities[: len(positive)].sum())


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok", "model": MODEL_NAME}


@app.post("/classify")
async def classify(request: Request) -> dict:
    data = await request.body()
    if not data:
        raise HTTPException(status_code=400, detail="imagen vacía")
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="imagen demasiado grande")
    started = time.perf_counter()
    try:
        pixels = preprocess(data)
    except Exception:
        raise HTTPException(status_code=415, detail="no se pudo leer la imagen") from None
    vector = session.run(["image_embeds"], {INPUT_NAME: pixels})[0][0]
    vector = vector / np.linalg.norm(vector)
    result = {group: round(score(vector, group), 4) for group in GROUPS}
    result["model"] = MODEL_NAME
    result["millis"] = round((time.perf_counter() - started) * 1000)
    return result
