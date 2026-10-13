package com.pawparazzi.media.storage;

import static org.assertj.core.api.Assertions.assertThat;

import com.pawparazzi.common.config.AppProperties;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/**
 * Prueba el adaptador contra un servidor S3 real (SeaweedFS de compose.yaml).
 * Se ejecuta solo si existe S3_IT_ENDPOINT, p. ej.:
 * <pre>
 * S3_IT_ENDPOINT=http://localhost:8333 S3_ACCESS_KEY=... S3_SECRET_KEY=... ./mvnw test -Dtest=S3StorageServiceIT
 * </pre>
 */
@EnabledIfEnvironmentVariable(named = "S3_IT_ENDPOINT", matches = ".+")
class S3StorageServiceIT {

    @Test
    void createsBucketAndStoresReadsAndDeletesObjects() {
        String bucket = "pawparazzi-it-" + UUID.randomUUID().toString().substring(0, 8);
        AppProperties props = new AppProperties(null, null, null,
                new AppProperties.Storage("s3", null, new AppProperties.Storage.S3(
                        System.getenv("S3_IT_ENDPOINT"), "us-east-1", bucket,
                        System.getenv("S3_ACCESS_KEY"), System.getenv("S3_SECRET_KEY"), true, true)),
                null, null, null);
        S3StorageService storage = new S3StorageService(props);
        try {
            byte[] content = "foto".getBytes(StandardCharsets.UTF_8);
            storage.put("media/u/1.jpg", content, "image/jpeg");

            assertThat(storage.get("media/u/1.jpg")).contains(content);
            assertThat(storage.get("media/u/no-existe.jpg")).isEmpty();

            storage.delete("media/u/1.jpg");
            assertThat(storage.get("media/u/1.jpg")).isEmpty();

            // Arrancar de nuevo con el bucket ya creado no falla.
            new S3StorageService(props).close();
        } finally {
            storage.close();
        }
    }
}
