package com.pawparazzi.media.moderation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.media.moderation.ImageModerator.Reason;
import com.pawparazzi.media.moderation.ImageModerator.Status;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** El cliente del servicio de revisión contra un servidor HTTP de prueba (sin el modelo real). */
class LocalImageModeratorTest {

    private HttpServer server;
    private final AtomicReference<String> responseBody = new AtomicReference<>();
    private final AtomicReference<Integer> responseStatus = new AtomicReference<>(200);
    private final AtomicReference<byte[]> receivedBody = new AtomicReference<>();
    private LocalImageModerator moderator;

    @BeforeEach
    void start() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/classify", exchange -> {
            receivedBody.set(exchange.getRequestBody().readAllBytes());
            byte[] body = responseBody.get().getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(responseStatus.get(), body.length);
            exchange.getResponseBody().write(body);
            exchange.close();
        });
        server.start();
        moderator = moderatorFor("http://127.0.0.1:" + server.getAddress().getPort() + "/");
    }

    @AfterEach
    void stop() {
        server.stop(0);
    }

    private static LocalImageModerator moderatorFor(String url) {
        var local = new AppProperties.Moderation.Local(url, Duration.ofSeconds(2), 0.5, 0.85, 0.85);
        var props = new AppProperties(null, null, null, null, null,
                new AppProperties.Moderation("local", "allow", local), null);
        return new LocalImageModerator(props, new ObjectMapper());
    }

    private void scores(double animal, double violence, double sexual) {
        responseBody.set("{\"animal\":%s,\"violence\":%s,\"sexual\":%s,\"model\":\"clip-test\",\"millis\":5}"
                .formatted(animal, violence, sexual));
    }

    @Test
    void approvesAPetPhotoAndSendsTheImageBytes() {
        scores(0.97, 0.01, 0.0);
        byte[] image = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2, 3};

        var result = moderator.review(image, true);

        assertThat(result.status()).isEqualTo(Status.APPROVED);
        assertThat(result.provider()).isEqualTo("local:clip-test");
        assertThat(receivedBody.get()).isEqualTo(image);
    }

    @Test
    void rejectsWhenNoAnimalIsDetected() {
        scores(0.12, 0.0, 0.0);
        assertThat(moderator.review(new byte[]{1}, true).reason()).isEqualTo(Reason.NOT_AN_ANIMAL);
        // El avatar de persona no necesita animal.
        assertThat(moderator.review(new byte[]{1}, false).status()).isEqualTo(Status.APPROVED);
    }

    @Test
    void safetyThresholdsAreStrictAndWinOverTheAnimalCheck() {
        scores(0.9, 0.9, 0.0);
        assertThat(moderator.review(new byte[]{1}, true).reason()).isEqualTo(Reason.VIOLENCE);
        scores(0.1, 0.0, 0.95);
        assertThat(moderator.review(new byte[]{1}, false).reason()).isEqualTo(Reason.SEXUAL_CONTENT);
        // Por debajo del umbral de seguridad no se rechaza.
        scores(0.9, 0.84, 0.84);
        assertThat(moderator.review(new byte[]{1}, true).status()).isEqualTo(Status.APPROVED);
    }

    @Test
    void failuresAreReportedAsUnavailableNotAsAVerdict() {
        responseStatus.set(500);
        responseBody.set("{}");
        assertThatThrownBy(() -> moderator.review(new byte[]{1}, true))
                .isInstanceOf(ImageModerator.ModerationUnavailableException.class);

        responseStatus.set(200);
        responseBody.set("{\"animal\":0.9}");
        assertThatThrownBy(() -> moderator.review(new byte[]{1}, true))
                .isInstanceOf(ImageModerator.ModerationUnavailableException.class);

        // Servicio apagado.
        var unreachable = moderatorFor("http://127.0.0.1:1");
        assertThatThrownBy(() -> unreachable.review(new byte[]{1}, true))
                .isInstanceOf(ImageModerator.ModerationUnavailableException.class);
    }
}
