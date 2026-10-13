"""Descripciones con las que se compara cada foto.

CLIP puntúa la similitud entre la imagen y cada frase. Para cada pregunta hay frases "positivas"
(lo que buscamos detectar) y "neutras" (todo lo demás); la puntuación es la parte de probabilidad
que se llevan las positivas. Las frases van en inglés porque el modelo se entrenó sobre todo en inglés.

Cambiar estas listas cambia el comportamiento del filtro: hay que reconstruir la imagen y volver a
pasar `test_images.py` con fotos de ejemplo.
"""

ANIMAL_POSITIVE = [
    "a photo of a dog",
    "a photo of a cat",
    "a photo of a puppy or a kitten",
    "a photo of a pet bird or a parrot",
    "a photo of a rabbit",
    "a photo of a hamster or a guinea pig",
    "a photo of a pet reptile, a turtle or a lizard",
    "a photo of a fish in an aquarium",
    "a photo of a horse",
    "a photo of an animal",
    "a photo of a person with their pet",
    "a blurry photo of a pet moving",
]

ANIMAL_NEUTRAL = [
    "a photo of a person",
    "a selfie",
    "a photo of a group of people",
    "a photo of two people together",
    "a photo of a person carrying another person",
    "an old black and white photo of people",
    "a photo of a child",
    "a photo of food",
    "a photo of an object",
    "a photo of a room with no animals",
    "a photo of a landscape",
    "a photo of a building or a street",
    "a photo of a car",
    "a screenshot",
    "a document or a page of text",
    "a logo or an icon",
    "a drawing or a cartoon",
    "a cartoon or an illustration of an animal",
    "a painting of an animal",
    "a statue or a sculpture of an animal",
    "a stuffed toy or a plush animal",
    "a meme with text",
]

VIOLENCE_POSITIVE = [
    "a photo of blood and gore",
    "a photo of a severe bleeding wound",
    "a photo of a dead animal",
    "a photo of a person hitting or abusing an animal",
    "a photo of people fighting violently",
    "a photo of a weapon pointed at someone",
    "a photo of a dead body",
]

SEXUAL_POSITIVE = [
    "a photo of a naked person",
    "pornography",
    "a photo of people having sex",
    "an explicit sexual photo",
]

# Frases neutras compartidas por las preguntas de seguridad: fotos normales de una app de mascotas.
SAFE_NEUTRAL = [
    "a normal harmless photo",
    "a photo of a pet",
    "a photo of a pet sleeping",
    "a photo of pets playing",
    "a photo of a dog with its mouth open",
    "a photo of a pet at the vet",
    "a photo of a person wearing clothes",
    "a photo of a person hugging a pet",
    "a photo of people at the beach or a swimming pool",
    "a photo of food",
    "a photo of an object",
    "a photo of a landscape",
    "a screenshot",
    "a drawing or a cartoon",
]

GROUPS = {
    "animal": (ANIMAL_POSITIVE, ANIMAL_NEUTRAL),
    "violence": (VIOLENCE_POSITIVE, SAFE_NEUTRAL),
    "sexual": (SEXUAL_POSITIVE, SAFE_NEUTRAL),
}
