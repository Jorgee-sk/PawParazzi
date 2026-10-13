package com.pawparazzi.friendships;

import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
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
@Tag(name = "Amistades")
public class FriendshipController {

    public record SendRequest(@NotBlank @Size(max = 31) String username) {
    }

    private final FriendshipService service;

    public FriendshipController(FriendshipService service) {
        this.service = service;
    }

    @Operation(summary = "Envía una solicitud por nombre de usuario (acepta automáticamente si había una inversa)")
    @PostMapping("/friend-requests")
    public FriendshipService.FriendRequestView send(@CurrentUserId UUID userId, @Valid @RequestBody SendRequest body) {
        return service.sendRequest(userId, body.username());
    }

    @Operation(summary = "Solicitudes pendientes recibidas (incoming) o enviadas (outgoing)")
    @GetMapping("/friend-requests")
    public List<FriendshipService.FriendRequestView> list(@CurrentUserId UUID userId,
                                                          @RequestParam(defaultValue = "incoming") String direction) {
        return "outgoing".equals(direction) ? service.outgoing(userId) : service.incoming(userId);
    }

    @PostMapping("/friend-requests/{id}/accept")
    public FriendshipService.FriendRequestView accept(@CurrentUserId UUID userId, @PathVariable UUID id) {
        return service.accept(userId, id);
    }

    @PostMapping("/friend-requests/{id}/reject")
    public FriendshipService.FriendRequestView reject(@CurrentUserId UUID userId, @PathVariable UUID id) {
        return service.reject(userId, id);
    }

    @Operation(summary = "Cancela una solicitud enviada")
    @DeleteMapping("/friend-requests/{id}")
    public ResponseEntity<Void> cancel(@CurrentUserId UUID userId, @PathVariable UUID id) {
        service.cancel(userId, id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/friends")
    public List<FriendshipService.FriendView> friends(@CurrentUserId UUID userId) {
        return service.listFriends(userId);
    }

    @DeleteMapping("/friends/{friendId}")
    public ResponseEntity<Void> remove(@CurrentUserId UUID userId, @PathVariable UUID friendId) {
        service.removeFriend(userId, friendId);
        return ResponseEntity.noContent().build();
    }
}
