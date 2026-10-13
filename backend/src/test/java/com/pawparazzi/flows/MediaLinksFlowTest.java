package com.pawparazzi.flows;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.pawparazzi.media.ImageProcessorTest;
import com.pawparazzi.media.MediaLinks;
import com.pawparazzi.media.moderation.ImageModerator;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.ResultActions;

/** Imágenes con enlaces firmados (almacenamiento local: el enlace apunta a la propia API). */
class MediaLinksFlowTest extends ApiTestSupport {

    @MockitoSpyBean
    Clock clock;

    private void befriend(Account from, Account to) throws Exception {
        JsonNode request = body(mvc.perform(auth(post("/api/v1/friend-requests"), from.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("username", to.username())))));
        mvc.perform(auth(post("/api/v1/friend-requests/" + request.get("id").asText() + "/accept"), to.token()))
                .andExpect(status().isOk());
    }

    private ResultActions refresh(Account who, String url) throws Exception {
        return mvc.perform(auth(post("/api/v1/media/links/refresh"), who.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("url", url))));
    }

    @Test
    void signedLinksWorkWithoutTokenAndCannotBeForged() throws Exception {
        Account elena = registerWithProfile("Elena");
        UUID pet = createPet(elena, "Nube");
        JsonNode post = body(publish(elena, "FREE", upload(elena, "POST"), pet, UUID.randomUUID().toString())
                .andExpect(status().isCreated())).get("post");
        String full = post.at("/image/url").asText();
        String thumb = post.at("/image/thumbnailUrl").asText();
        assertThat(full).startsWith("/api/v1/media/").contains("/content?variant=full&exp=").contains("&sig=");

        // Sin cabecera de autorización: la firma basta. El contenido es el JPEG guardado.
        byte[] bytes = mvc.perform(get(full))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "image/jpeg"))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andReturn().getResponse().getContentAsByteArray();
        assertThat(bytes).startsWith(0xFF, 0xD8, 0xFF);
        mvc.perform(get(thumb)).andExpect(status().isOk());

        // Firma alterada, firma de otra variante, caducidad alargada o sin firma: rechazado.
        mvc.perform(get(full.substring(0, full.length() - 2) + "xx")).andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("link_expired"));
        mvc.perform(get(full.replace("variant=full", "variant=thumb"))).andExpect(status().isForbidden());
        String exp = full.replaceAll(".*exp=(\\d+).*", "$1");
        mvc.perform(get(full.replace("exp=" + exp, "exp=" + (Long.parseLong(exp) + 3600))))
                .andExpect(status().isForbidden());
        mvc.perform(get(full.substring(0, full.indexOf("&sig=")))).andExpect(status().isBadRequest());

        // La firma de una imagen no sirve para otra.
        String otherId = upload(elena, "POST").toString();
        String mediaId = MediaLinks.parse(full).orElseThrow().mediaId().toString();
        mvc.perform(get(full.replace(mediaId, otherId))).andExpect(status().isForbidden());
    }

    @Test
    void expiredLinksStopWorkingAndRefreshChecksPermissionsAgain() throws Exception {
        Account elena = registerWithProfile("Elena");
        Account dani = registerWithProfile("Dani");
        Account extra = registerWithProfile("Ajena");
        UUID pet = createPet(elena, "Nube");
        publish(elena, "FREE", upload(elena, "POST"), pet, UUID.randomUUID().toString()).andExpect(status().isCreated());
        befriend(dani, elena);
        String link = body(mvc.perform(auth(get("/api/v1/feed/friends"), dani.token())))
                .at("/items/0/image/thumbnailUrl").asText();
        mvc.perform(get(link)).andExpect(status().isOk());

        // Pasan siete horas (la validez por defecto es de seis): el enlace caduca.
        Instant later = Instant.now().plusSeconds(7 * 3600);
        when(clock.instant()).thenReturn(later);
        when(clock.getZone()).thenReturn(ZoneOffset.UTC);
        mvc.perform(get(link)).andExpect(status().isForbidden());

        // Dani sigue siendo amigo: puede renovarlo y el nuevo enlace funciona.
        String renewed = body(refresh(dani, link).andExpect(status().isOk())).get("url").asText();
        assertThat(renewed).isNotEqualTo(link).contains("variant=thumb");
        mvc.perform(get(renewed)).andExpect(status().isOk());

        // Quien no puede ver la foto no puede renovar el enlace, aunque lo tenga.
        refresh(extra, link).andExpect(status().isNotFound());
        mvc.perform(post("/api/v1/media/links/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("url", link))))
                .andExpect(status().isUnauthorized());
        refresh(dani, "https://example.com/no-es-un-enlace").andExpect(status().isNotFound());

        // Tras dejar de ser amigos, Dani tampoco puede renovarlo.
        mvc.perform(auth(delete("/api/v1/friends/" + elena.id()), dani.token())).andExpect(status().isNoContent());
        refresh(dani, link).andExpect(status().isNotFound());
    }

    @Test
    void parsesBothKindsOfLinks() {
        UUID id = UUID.randomUUID();
        assertThat(MediaLinks.parse("/api/v1/media/" + id + "/content?variant=thumb&exp=1&sig=x"))
                .contains(new MediaLinks.Reference(id, MediaLinks.Variant.THUMB));
        assertThat(MediaLinks.parse("/api/v1/media/" + id + "/content?variant=full&exp=1&sig=x"))
                .contains(new MediaLinks.Reference(id, MediaLinks.Variant.FULL));
        // Enlace prefirmado de S3: .../bucket/media/{dueño}/{imagen}[_thumb].jpg?X-Amz-...
        UUID owner = UUID.randomUUID();
        String s3 = "http://localhost:8333/pawparazzi-media/media/" + owner + "/" + id;
        assertThat(MediaLinks.parse(s3 + "_thumb.jpg?X-Amz-Signature=abc"))
                .contains(new MediaLinks.Reference(id, MediaLinks.Variant.THUMB));
        assertThat(MediaLinks.parse(s3 + ".jpg?X-Amz-Signature=abc"))
                .contains(new MediaLinks.Reference(id, MediaLinks.Variant.FULL));
        assertThat(MediaLinks.parse("http://localhost/otra-cosa.jpg")).isEmpty();
        assertThat(MediaLinks.parse(null)).isEmpty();
    }

    /** Con un solo hueco de procesado y espera mínima, la segunda subida simultánea recibe 503. */
    @Nested
    @TestPropertySource(properties = {
            "pawparazzi.media.max-concurrent-processing=1",
            "pawparazzi.media.processing-wait=PT0.2S"})
    class UploadLimit extends ApiTestSupport {

        @MockitoBean
        ImageModerator moderator;

        @MockitoSpyBean
        com.pawparazzi.media.ImageProcessor slowProcessor;

        @Test
        void aSecondSimultaneousUploadGetsServerBusyInsteadOfExhaustingMemory() throws Exception {
            when(moderator.review(any(), anyBoolean())).thenReturn(ImageModerator.Result.approved("fake"));
            CountDownLatch processing = new CountDownLatch(1);
            CountDownLatch release = new CountDownLatch(1);
            org.mockito.Mockito.doAnswer(invocation -> {
                processing.countDown();
                release.await(10, TimeUnit.SECONDS);
                return invocation.callRealMethod();
            }).when(slowProcessor).process(any());

            Account a = registerWithProfile("Subidas");
            MockMultipartFile file = new MockMultipartFile("file", "foto.jpg", "image/jpeg",
                    ImageProcessorTest.TestImages.jpeg(64, 48));
            var first = new Thread(() -> {
                try {
                    mvc.perform(auth(multipart("/api/v1/media").file(file).param("purpose", "POST"), a.token()))
                            .andExpect(status().isCreated());
                } catch (Exception e) {
                    throw new RuntimeException(e);
                }
            });
            first.start();
            assertThat(processing.await(5, TimeUnit.SECONDS)).isTrue();

            // La primera sigue procesándose: la segunda no entra.
            mvc.perform(auth(multipart("/api/v1/media").file(file).param("purpose", "POST"), a.token()))
                    .andExpect(status().isServiceUnavailable())
                    .andExpect(jsonPath("$.code").value("server_busy"));

            release.countDown();
            first.join(10_000);
            org.mockito.Mockito.reset(slowProcessor);

            // Con el hueco libre vuelve a aceptar subidas.
            mvc.perform(auth(multipart("/api/v1/media").file(file).param("purpose", "POST"), a.token()))
                    .andExpect(status().isCreated());
        }
    }
}
