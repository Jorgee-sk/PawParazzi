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
        public record S3(String endpoint, String region, String bucket, String accessKey, String secretKey,
                         boolean pathStyleAccess, boolean createBucketIfMissing) {
        }
    }

    public record Media(long maxUploadBytes, long maxPixels, int maxDimension, int thumbnailDimension,
                        float jpegQuality) {
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
