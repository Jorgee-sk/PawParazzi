package com.pawparazzi.comments;

import com.pawparazzi.common.security.CurrentUserId;
import com.pawparazzi.moments.PostDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "Comentarios")
public class CommentController {

    public record AddCommentRequest(
            @NotBlank(message = "Escribe algo antes de enviar.")
            @Size(max = 500, message = "Máximo 500 caracteres.") String body) {
    }

    private final CommentService service;

    public CommentController(CommentService service) {
        this.service = service;
    }

    @Operation(summary = "Comentarios de una publicación visible, del más antiguo al más reciente")
    @GetMapping("/posts/{postId}/comments")
    public PostDtos.PageResponse<CommentService.CommentView> list(@CurrentUserId UUID userId,
                                                                  @PathVariable UUID postId,
                                                                  @RequestParam(required = false) String cursor,
                                                                  @RequestParam(required = false) Integer limit) {
        return service.list(userId, postId, cursor, limit);
    }

    @PostMapping("/posts/{postId}/comments")
    public ResponseEntity<CommentService.CommentView> add(@CurrentUserId UUID userId, @PathVariable UUID postId,
                                                          @Valid @RequestBody AddCommentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.add(userId, postId, request.body()));
    }

    @Operation(summary = "Borra un comentario propio, o cualquiera de una publicación propia")
    @DeleteMapping("/comments/{commentId}")
    public ResponseEntity<Void> delete(@CurrentUserId UUID userId, @PathVariable UUID commentId) {
        service.delete(userId, commentId);
        return ResponseEntity.noContent().build();
    }
}
