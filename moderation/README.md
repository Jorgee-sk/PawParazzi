# Revisión automática de fotos

Servicio propio que puntúa cada foto antes de que el backend la guarde. Usa **CLIP ViT-B/32** (modelo abierto
de OpenAI, licencia MIT) en formato ONNX y en CPU: no hay coste por foto y las imágenes no salen de tu servidor.

## Cómo funciona

CLIP mide el parecido entre una imagen y una frase. `prompts.py` tiene, para cada pregunta, frases de lo que
se busca y frases neutras; la puntuación es la parte de probabilidad que se llevan las primeras.

| Puntuación | Pregunta | El backend rechaza si… |
|---|---|---|
| `animal` | ¿Aparece un animal real? | es menor que `MODERATION_ANIMAL_THRESHOLD` (0,5) en publicaciones y fotos de mascota |
| `violence` | ¿Violencia, sangre, heridas graves, animales muertos? | es mayor o igual que `MODERATION_VIOLENCE_THRESHOLD` (0,85) |
| `sexual` | ¿Desnudez o contenido sexual? | es mayor o igual que `MODERATION_SEXUAL_THRESHOLD` (0,85) |

El servicio solo puntúa. La decisión, los umbrales y los mensajes están en el backend.

```
POST /classify   cuerpo: bytes JPEG o PNG
→ {"animal": 0.99, "violence": 0.03, "sexual": 0.0, "model": "clip-vit-base-patch32", "millis": 31}
GET /healthz
```

## Recursos

Medido en el equipo de desarrollo (CPU, 2 hilos): imagen de 705 MB, unos 770 MB de memoria en reposo y
alrededor de 30 ms por foto. `MODERATION_THREADS` fija los hilos por petición.

## Resultados de la prueba

Con una muestra de 56 fotos de Wikimedia Commons (`python moderation/test_images.py`, 13/10/2026):

- Fotos reales de mascotas (perros, gatos, loro, hámster, peces, tortugas, caballos, perro en el veterinario,
  perros jugando a pelearse): todas aceptadas.
- Sin animal (retratos, comida, paisajes, coches, capturas de pantalla, peluches, interiores, gente en la
  playa): todas rechazadas.
- Cuadros, dibujos y estatuas de animales: rechazados, porque se pide un animal real.
- Heridas sangrantes, un animal atropellado y un combate de boxeo: rechazados por violencia.
- Fotografía de desnudo y estatuas desnudas: rechazadas por contenido sexual.

### Limitaciones conocidas

- La muestra es pequeña y sus etiquetas salen de la búsqueda, no de una revisión foto a foto. Violencia y
  contenido sexual se han probado con muy pocos ejemplos (6 y 4): no hay una tasa de acierto fiable.
- Dos perros jugando a pelearse puntúan 0,71 en violencia: por debajo del umbral, pero cerca. Si bajas ese
  umbral, empezarán a rechazarse fotos de juego.
- Las estatuas desnudas se rechazan igual que la fotografía de desnudo.
- Un filtro así se puede esquivar y se equivoca. Debe ir acompañado de la opción de reportar contenido
  (pendiente en el roadmap).

## Ajustarlo

1. **Umbrales**: cambia `MODERATION_*_THRESHOLD` en `.env` y reinicia el backend. No hace falta reconstruir nada.
2. **Frases**: edita `prompts.py` y reconstruye la imagen. La descarga del modelo queda en caché; solo se
   recalculan los vectores:

   ```
   podman build -t localhost/pawparazzi-moderation:latest moderation
   python -m podman_compose up -d --force-recreate moderation
   ```

3. **Comprueba el efecto** antes de darlo por bueno:

   ```
   python moderation/test_images.py              # muestra de Wikimedia Commons
   python moderation/test_images.py mis-fotos/   # tus propias fotos, para ver sus puntuaciones
   ```

## Ficheros

| Fichero | Para qué |
|---|---|
| `app.py` | Servicio HTTP: preprocesa la imagen, ejecuta el modelo y devuelve las puntuaciones |
| `prompts.py` | Las frases con las que se compara cada foto |
| `build_embeddings.py` | Se ejecuta al construir la imagen: descarga el modelo y convierte las frases en vectores |
| `Containerfile` | Construcción en dos etapas; la imagen final solo lleva el modelo de visión y los vectores |
| `test_images.py` | Prueba el servicio con fotos de ejemplo |
