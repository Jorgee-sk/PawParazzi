package com.pawparazzi.pets;

import com.pawparazzi.common.security.CurrentUserId;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "Mascotas")
public class PetController {

    private final PetService service;

    public PetController(PetService service) {
        this.service = service;
    }

    @Operation(summary = "Mis mascotas")
    @GetMapping("/pets")
    public List<PetDtos.PetResponse> mine(@CurrentUserId UUID userId) {
        return service.listMine(userId);
    }

    @Operation(summary = "Mascotas de una amistad")
    @GetMapping("/users/{ownerId}/pets")
    public List<PetDtos.PetResponse> ofUser(@CurrentUserId UUID userId, @PathVariable UUID ownerId) {
        return service.listOf(ownerId, userId);
    }

    @Operation(summary = "Perfil de una mascota propia o de una amistad")
    @GetMapping("/pets/{petId}")
    public PetDtos.PetResponse get(@CurrentUserId UUID userId, @PathVariable UUID petId) {
        return service.get(petId, userId);
    }

    @PostMapping("/pets")
    public ResponseEntity<PetDtos.PetResponse> create(@CurrentUserId UUID userId,
                                                      @Valid @RequestBody PetDtos.PetRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(service.create(userId, request));
    }

    @PutMapping("/pets/{petId}")
    public PetDtos.PetResponse update(@CurrentUserId UUID userId, @PathVariable UUID petId,
                                      @Valid @RequestBody PetDtos.PetRequest request) {
        return service.update(userId, petId, request);
    }

    @DeleteMapping("/pets/{petId}")
    public ResponseEntity<Void> delete(@CurrentUserId UUID userId, @PathVariable UUID petId) {
        service.delete(userId, petId);
        return ResponseEntity.noContent().build();
    }
}
