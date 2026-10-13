package com.pawparazzi.users;

import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me")
@Tag(name = "Perfil")
public class UserController {

    public record DeleteAccountRequest(
            @NotBlank(message = "Escribe tu contraseña para confirmar.") @Size(max = 128) String password) {
    }

    private final UserService service;
    private final AccountDeletionService deletion;

    public UserController(UserService service, AccountDeletionService deletion) {
        this.service = service;
        this.deletion = deletion;
    }

    @Operation(summary = "Perfil de la persona autenticada")
    @GetMapping
    public UserDtos.MeResponse me(@CurrentUserId UUID userId) {
        return service.me(userId);
    }

    @Operation(summary = "Actualiza username, nombre visible, zona horaria o avatar")
    @PatchMapping
    public UserDtos.MeResponse update(@CurrentUserId UUID userId, @Valid @RequestBody UserDtos.UpdateMeRequest request) {
        return service.update(userId, request);
    }

    @Operation(summary = "Elimina la cuenta y todos sus datos de forma definitiva (confirma con la contraseña)")
    @DeleteMapping
    public ResponseEntity<Void> delete(@CurrentUserId UUID userId, @Valid @RequestBody DeleteAccountRequest request) {
        deletion.deleteAccount(userId, request.password());
        return ResponseEntity.noContent().build();
    }
}
