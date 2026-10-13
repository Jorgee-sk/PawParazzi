package com.pawparazzi.flows;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

/**
 * Flujo de aceptación del MVP: registro → perfil → mascota → publicar → compartir con amistades.
 * Verifica también visibilidad en servidor, idempotencia y racha.
 */
class MvpSocialFlowTest extends ApiTestSupport {

    @Test
    void publishAndShareWithFriendsEndToEnd() throws Exception {
        Account elena = registerWithProfile("Elena");
        Account dani = registerWithProfile("Dani");
        UUID nube = createPet(elena, "Nube");

        // PawMoment: cuenta para la racha (dentro o fuera de la ventana, nunca bloquea).
        UUID photo1 = upload(elena, "POST");
        String requestId = UUID.randomUUID().toString();
        JsonNode created = body(publish(elena, "PAW_MOMENT", photo1, nube, requestId)
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.streakCounted").value(true))
                .andExpect(jsonPath("$.post.type").value("PAW_MOMENT"))
                .andExpect(jsonPath("$.post.onTime").isBoolean())
                .andExpect(jsonPath("$.post.pets[0].name").value("Nube"))
                .andExpect(jsonPath("$.post.isMine").value(true)));
        UUID momentId = UUID.fromString(created.at("/post/id").asText());

        // Reintento de red con el mismo clientRequestId: no duplica ni vuelve a contar.
        publish(elena, "PAW_MOMENT", photo1, nube, requestId)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.replayed").value(true))
                .andExpect(jsonPath("$.streakCounted").value(false))
                .andExpect(jsonPath("$.post.id").value(momentId.toString()));

        // Segundo PawMoment el mismo día → 409 con alternativa (Foto libre).
        UUID photo2 = upload(elena, "POST");
        publish(elena, "PAW_MOMENT", photo2, nube, UUID.randomUUID().toString())
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("already_participated"));

        // Foto libre: siempre permitida, no suma racha.
        publish(elena, "FREE", photo2, nube, UUID.randomUUID().toString())
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.streakCounted").value(false))
                .andExpect(jsonPath("$.post.onTime").doesNotExist());

        mvc.perform(auth(get("/api/v1/gamification/streak"), elena.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.current").value(1))
                .andExpect(jsonPath("$.best").value(1))
                .andExpect(jsonPath("$.totalDays").value(1))
                .andExpect(jsonPath("$.participatedToday").value(true))
                .andExpect(jsonPath("$.nextMilestone").value(3));

        mvc.perform(auth(get("/api/v1/moments/today"), elena.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.participated").value(true))
                .andExpect(jsonPath("$.postId").value(momentId.toString()));

        // Antes de ser amigos, Dani no ve nada de Elena (404, sin revelar existencia).
        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));
        mvc.perform(auth(get("/api/v1/posts/" + momentId), dani.token())).andExpect(status().isNotFound());
        mvc.perform(auth(get("/api/v1/pets/" + nube), dani.token())).andExpect(status().isNotFound());
        mvc.perform(auth(put("/api/v1/posts/" + momentId + "/reactions/me"), dani.token()))
                .andExpect(status().isNotFound());

        // Solicitud de amistad por username → aceptación.
        JsonNode request = body(mvc.perform(auth(post("/api/v1/friend-requests"), dani.token())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("username", "@" + elena.username()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING")));
        mvc.perform(auth(get("/api/v1/friend-requests?direction=incoming"), elena.token()))
                .andExpect(jsonPath("$[0].requester.username").value(dani.username()));
        // Solo la persona destinataria puede aceptar.
        mvc.perform(auth(post("/api/v1/friend-requests/" + request.get("id").asText() + "/accept"), dani.token()))
                .andExpect(status().isNotFound());
        mvc.perform(auth(post("/api/v1/friend-requests/" + request.get("id").asText() + "/accept"), elena.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACCEPTED"));

        // Ahora Dani ve las publicaciones de Elena, de más reciente a más antigua.
        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.items[0].type").value("FREE"))
                .andExpect(jsonPath("$.items[1].type").value("PAW_MOMENT"))
                .andExpect(jsonPath("$.items[1].author.username").value(elena.username()))
                .andExpect(jsonPath("$.items[1].author.email").doesNotExist())
                .andExpect(jsonPath("$.items[1].isMine").value(false));
        // El feed de Dani trae un enlace firmado a la foto, que se descarga sin token.
        String imageUrl = body(mvc.perform(auth(get("/api/v1/feed/friends"), dani.token())))
                .at("/items/1/image/thumbnailUrl").asText();
        mvc.perform(get(imageUrl)).andExpect(status().isOk());
        mvc.perform(auth(get("/api/v1/pets/" + nube + "/posts"), dani.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(2));

        // Cariños: idempotentes.
        mvc.perform(auth(put("/api/v1/posts/" + momentId + "/reactions/me"), dani.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.count").value(1))
                .andExpect(jsonPath("$.reactedByMe").value(true));
        mvc.perform(auth(put("/api/v1/posts/" + momentId + "/reactions/me"), dani.token()))
                .andExpect(jsonPath("$.count").value(1));
        mvc.perform(auth(get("/api/v1/posts/" + momentId), elena.token()))
                .andExpect(jsonPath("$.reactions.count").value(1))
                .andExpect(jsonPath("$.reactions.reactedByMe").value(false));
        mvc.perform(auth(delete("/api/v1/posts/" + momentId + "/reactions/me"), dani.token()))
                .andExpect(jsonPath("$.count").value(0));

        // Dani no puede borrar la publicación de Elena.
        mvc.perform(auth(delete("/api/v1/posts/" + momentId), dani.token())).andExpect(status().isNotFound());

        // Al eliminar la amistad se pierde el acceso.
        mvc.perform(auth(delete("/api/v1/friends/" + elena.id()), dani.token())).andExpect(status().isNoContent());
        mvc.perform(auth(get("/api/v1/feed/friends"), dani.token()))
                .andExpect(jsonPath("$.items.length()").value(0));
    }

    @Test
    void feedIsPaginatedWithCursor() throws Exception {
        Account a = registerWithProfile("Paginas");
        UUID pet = createPet(a, "Miso");
        for (int i = 0; i < 3; i++) {
            publish(a, "FREE", upload(a, "POST"), pet, UUID.randomUUID().toString()).andExpect(status().isCreated());
        }
        JsonNode first = body(mvc.perform(auth(get("/api/v1/feed/friends?limit=2"), a.token()))
                .andExpect(status().isOk()));
        assertThat(first.get("items")).hasSize(2);
        String cursor = first.get("nextCursor").asText();
        JsonNode second = body(mvc.perform(auth(get("/api/v1/feed/friends?limit=2&cursor=" + cursor), a.token()))
                .andExpect(status().isOk()));
        assertThat(second.get("items")).hasSize(1);
        assertThat(second.get("nextCursor")).isNull();
        List<String> ids = List.of(first.at("/items/0/id").asText(), first.at("/items/1/id").asText(),
                second.at("/items/0/id").asText());
        assertThat(ids).doesNotHaveDuplicates();

        mvc.perform(auth(get("/api/v1/feed/friends?cursor=basura"), a.token())).andExpect(status().isBadRequest());
    }

    @Test
    void cannotPublishWithOtherPeoplesMediaOrPets() throws Exception {
        Account a = registerWithProfile("Propia");
        Account b = registerWithProfile("Ajena");
        UUID petA = createPet(a, "Kira");
        UUID petB = createPet(b, "Toby");
        UUID mediaB = upload(b, "POST");

        publish(a, "FREE", mediaB, petA, UUID.randomUUID().toString())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_media"));
        publish(a, "FREE", upload(a, "POST"), petB, UUID.randomUUID().toString())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_pets"));
        // Una foto de mascota no puede publicarse como post.
        publish(a, "FREE", upload(a, "PET_PHOTO"), petA, UUID.randomUUID().toString())
                .andExpect(status().isBadRequest());
    }

    @Test
    void uploadRejectsNonImageContent() throws Exception {
        Account a = registerWithProfile("Subida");
        var fake = new org.springframework.mock.web.MockMultipartFile("file", "foto.jpg", "image/jpeg",
                "esto no es una imagen".getBytes());
        mvc.perform(auth(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .multipart("/api/v1/media").file(fake).param("purpose", "POST"), a.token()))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.code").value("unsupported_image"));
    }
}
