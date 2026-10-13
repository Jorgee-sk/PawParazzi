package com.pawparazzi.media.moderation;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pawparazzi.common.config.AppProperties;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Revisión con el servicio propio de PawParazzi (carpeta {@code moderation/}): un modelo abierto
 * (CLIP) que corre en nuestro contenedor, sin coste por foto y sin enviar imágenes a terceros.
 *
 * <p>El servicio devuelve tres puntuaciones entre 0 y 1 (animal, violence, sexual). Los umbrales
 * se configuran aquí: el de animal es permisivo (basta con que sea lo más probable) y los de
 * seguridad son exigentes, para no rechazar fotos normales por error.</p>
 */
@Component
@ConditionalOnProperty(name = "pawparazzi.moderation.provider", havingValue = "local")
public class LocalImageModerator implements ImageModerator {

    private static final Logger log = LoggerFactory.getLogger(LocalImageModerator.class);

    private final HttpClient http;
    private final ObjectMapper json;
    private final URI classifyUri;
    private final AppProperties.Moderation.Local config;

    public LocalImageModerator(AppProperties props, ObjectMapper json) {
        this.config = props.moderation().local();
        this.json = json;
        this.classifyUri = URI.create(config.url().replaceAll("/+$", "") + "/classify");
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
    }

    @Override
    public Result review(byte[] jpeg, boolean requireAnimal) {
        HttpRequest request = HttpRequest.newBuilder(classifyUri)
                .timeout(config.timeout())
                .header("Content-Type", "image/jpeg")
                .POST(HttpRequest.BodyPublishers.ofByteArray(jpeg))
                .build();
        JsonNode scores;
        try {
            HttpResponse<byte[]> response = http.send(request, HttpResponse.BodyHandlers.ofByteArray());
            if (response.statusCode() != 200) {
                throw new ModerationUnavailableException(
                        "El servicio de revisión respondió " + response.statusCode(), null);
            }
            scores = json.readTree(response.body());
        } catch (IOException e) {
            throw new ModerationUnavailableException("No se pudo contactar con el servicio de revisión", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new ModerationUnavailableException("Revisión interrumpida", e);
        }
        if (!scores.hasNonNull("animal") || !scores.hasNonNull("violence") || !scores.hasNonNull("sexual")) {
            throw new ModerationUnavailableException("Respuesta incompleta del servicio de revisión", null);
        }
        double animal = scores.get("animal").asDouble();
        double violence = scores.get("violence").asDouble();
        double sexual = scores.get("sexual").asDouble();
        log.debug("Revisión: animal={} violence={} sexual={}", animal, violence, sexual);

        var observation = new ModerationPolicy.Observation(
                animal >= config.animalThreshold(),
                violence >= config.violenceThreshold(),
                sexual >= config.sexualThreshold());
        return ModerationPolicy.decide(observation, requireAnimal, "local:" + scores.path("model").asText("?"));
    }
}
