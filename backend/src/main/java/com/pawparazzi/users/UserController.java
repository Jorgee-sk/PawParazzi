package com.pawparazzi.users;

import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me")
@Tag(name = "Perfil")
public class UserController {

    private final UserService service;

    public UserController(UserService service) {
        this.service = service;
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
}
