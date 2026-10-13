package com.pawparazzi.common.config;

import java.time.Duration;
import java.time.LocalTime;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "pawparazzi")
public record AppProperties(
        Jwt jwt,
        Cors cors,
        RateLimit rateLimit,
        Storage storage,
        Media media,
        Moderation moderation,
        PawMoment pawmoment) {

    public record Jwt(String secret, String issuer, Duration accessTokenTtl, Duration refreshTokenTtl) {
    }

    public record Cors(List<String> allowedOriginPatterns) {
    }

    public record RateLimit(int authRequestsPerMinute) {
    }

    public record Storage(String provider, Local local, S3 s3) {
        public record Local(String root) {
        }

        /**
         * @param createBucketIfMissing crea el bucket al arrancar si no existe (útil en desarrollo con
         *                              SeaweedFS; en producción el bucket debería aprovisionarse aparte).
         */
        /**
         * @param publicEndpoint        dirección con la que los clientes (app, navegador) llegan al
         *                              almacenamiento; puede ser una CDN. Los enlaces prefirmados se emiten
         *                              para este host. Si está vacío se usa {@code endpoint}.
         */
        public record S3(String endpoint, String publicEndpoint, String region, String bucket, String accessKey,
                         String secretKey, boolean pathStyleAccess, boolean createBucketIfMissing) {
        }
    }

    /**
     * @param linkTtl                 validez de los enlaces firmados a las imágenes
     * @param maxConcurrentProcessing imágenes que se decodifican y re-codifican a la vez (consume memoria)
     * @param processingWait          cuánto espera una subida a que haya hueco antes de responder 503
     */
    public record Media(long maxUploadBytes, long maxPixels, int maxDimension, int thumbnailDimension,
                        float jpegQuality, Duration linkTtl, int maxConcurrentProcessing,
                        Duration processingWait) {
    }

    /**
     * Revisión automática de imágenes.
     *
     * @param provider none (sin revisión) | local (servicio propio, carpeta moderation/)
     * @param onError  qué hacer si el proveedor falla: allow (se acepta sin revisar) | reject
     */
    public record Moderation(String provider, String onError, Local local) {
        /** Umbrales sobre las puntuaciones 0–1 del servicio. */
        public record Local(String url, Duration timeout, double animalThreshold, double violenceThreshold,
                            double sexualThreshold) {
        }

        public boolean rejectOnError() {
            return "reject".equalsIgnoreCase(onError);
        }
    }

    public record PawMoment(LocalTime earliestStart, LocalTime latestStart, Duration windowDuration) {
    }
}
