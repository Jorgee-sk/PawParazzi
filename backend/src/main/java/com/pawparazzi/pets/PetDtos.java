package com.pawparazzi.pets;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class PetDtos {

    private PetDtos() {
    }

    public record PetRequest(
            @NotBlank(message = "Ponle un nombre.") @Size(max = 40, message = "Máximo 40 caracteres.") String name,
            @NotNull(message = "Elige una especie.") Pet.Species species,
            @Size(max = 60) String breed,
            @PastOrPresent(message = "La fecha no puede ser futura.") LocalDate birthDate,
            Pet.Gender gender,
            @Size(max = 300, message = "Máximo 300 caracteres.") String description,
            @Size(max = 8, message = "Máximo 8 etiquetas.") List<@NotBlank @Size(max = 30) String> tags,
            UUID photoMediaId) {
    }

    public record PetResponse(UUID id, UUID ownerId, String name, String species, String breed, LocalDate birthDate,
                              String gender, String description, List<String> tags, String photoUrl,
                              String photoThumbnailUrl, boolean isMine) {
    }

    /** Lo mínimo para mostrar la mascota dentro de una publicación. */
    public record PetSummary(UUID id, String name, String species, String photoUrl) {
    }
}
