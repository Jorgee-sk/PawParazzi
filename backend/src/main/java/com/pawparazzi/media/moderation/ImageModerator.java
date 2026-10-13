package com.pawparazzi.media.moderation;

/**
 * Revisión automática de imágenes antes de guardarlas. Interfaz intercambiable: hoy hay un proveedor
 * local (modelo abierto en nuestro propio contenedor) y uno "sin revisión"; se puede añadir otro sin
 * tocar el resto del código.
 *
 * <p>Solo clasifica lo que se ve en la foto. No infiere emociones, intenciones ni salud del animal.</p>
 */
public interface ImageModerator {

    enum Status {
        /** Revisada y aceptada. */
        APPROVED,
        /** Revisada y rechazada: no se guarda. */
        REJECTED,
        /** No se pudo o no se quiso revisar (sin proveedor configurado o fallo del proveedor). */
        UNCHECKED
    }

    enum Reason {
        NOT_AN_ANIMAL("En la foto no vemos ninguna mascota. PawParazzi es solo para fotos de animales."),
        VIOLENCE("La foto parece mostrar violencia o heridas y no se puede publicar."),
        SEXUAL_CONTENT("La foto parece tener contenido sexual y no se puede publicar.");

        private final String userMessage;

        Reason(String userMessage) {
            this.userMessage = userMessage;
        }

        public String userMessage() {
            return userMessage;
        }
    }

    record Result(Status status, Reason reason, String provider) {

        public static Result approved(String provider) {
            return new Result(Status.APPROVED, null, provider);
        }

        public static Result rejected(Reason reason, String provider) {
            return new Result(Status.REJECTED, reason, provider);
        }

        public static Result unchecked(String provider) {
            return new Result(Status.UNCHECKED, null, provider);
        }
    }

    /**
     * @param jpeg          imagen ya normalizada (JPEG sin metadatos)
     * @param requireAnimal true para publicaciones y fotos de mascota; false para avatares de persona,
     *                      donde solo se comprueba que el contenido sea seguro
     * @throws ModerationUnavailableException si el proveedor falla; quien llama decide qué hacer
     */
    Result review(byte[] jpeg, boolean requireAnimal);

    class ModerationUnavailableException extends RuntimeException {
        public ModerationUnavailableException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
