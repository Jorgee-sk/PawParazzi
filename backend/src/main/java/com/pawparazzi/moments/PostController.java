package com.pawparazzi.moments;

import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "Publicaciones")
public class PostController {

    private final PostService service;

    public PostController(PostService service) {
        this.service = service;
    }

    @Operation(summary = "Publica un PawMoment o una foto libre (idempotente por clientRequestId)",
            description = "201 si se crea; 200 si es un reintento de una publicación ya creada. "
                    + "409 already_participated si ya hay PawMoment hoy.")
    @PostMapping("/posts")
    public ResponseEntity<PostDtos.CreatePostResponse> create(@CurrentUserId UUID userId,
                                                              @Valid @RequestBody PostDtos.CreatePostRequest request) {
        PostDtos.CreatePostResponse response = service.create(userId, request);
        return ResponseEntity.status(response.replayed() ? HttpStatus.OK : HttpStatus.CREATED).body(response);
    }

    @GetMapping("/posts/{postId}")
    public PostDtos.PostView get(@CurrentUserId UUID userId, @PathVariable UUID postId) {
        return service.get(postId, userId);
    }

    @Operation(summary = "Edita texto, mascotas y etiquetas de una publicación propia")
    @PatchMapping("/posts/{postId}")
    public PostDtos.PostView update(@CurrentUserId UUID userId, @PathVariable UUID postId,
                                    @Valid @RequestBody PostDtos.UpdatePostRequest request) {
        return service.update(userId, postId, request);
    }

    @DeleteMapping("/posts/{postId}")
    public ResponseEntity<Void> delete(@CurrentUserId UUID userId, @PathVariable UUID postId) {
        service.delete(userId, postId);
        return ResponseEntity.noContent().build();
    }

    @Operation(summary = "Feed de amigos (propias + amistades), paginado por cursor")
    @GetMapping("/feed/friends")
    public PostDtos.PageResponse<PostDtos.PostView> friendsFeed(@CurrentUserId UUID userId,
                                                                @RequestParam(required = false) String cursor,
                                                                @RequestParam(required = false) Integer limit) {
        return service.friendsFeed(userId, cursor, limit);
    }

    @Operation(summary = "Publicaciones de una mascota propia o de una amistad")
    @GetMapping("/pets/{petId}/posts")
    public PostDtos.PageResponse<PostDtos.PostView> petPosts(@CurrentUserId UUID userId, @PathVariable UUID petId,
                                                             @RequestParam(required = false) String cursor,
                                                             @RequestParam(required = false) Integer limit) {
        return service.petPosts(petId, userId, cursor, limit);
    }

    @Operation(summary = "Estado del PawMoment de hoy (ventana informativa; nunca bloquea)")
    @GetMapping("/moments/today")
    public PostDtos.TodayMoment today(@CurrentUserId UUID userId) {
        return service.today(userId);
    }
}
