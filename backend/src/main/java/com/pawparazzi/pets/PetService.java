package com.pawparazzi.pets;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.friendships.FriendshipService;
import com.pawparazzi.media.MediaAsset;
import com.pawparazzi.media.MediaService;
import com.pawparazzi.media.MediaUrls;
import java.time.Clock;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PetService {

    /** Límite razonable de perfiles por persona para el MVP. */
    static final int MAX_PETS_PER_USER = 20;

    private final PetRepository pets;
    private final MediaService media;
    private final FriendshipService friendships;
    private final Clock clock;

    public PetService(PetRepository pets, MediaService media, FriendshipService friendships, Clock clock) {
        this.pets = pets;
        this.media = media;
        this.friendships = friendships;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<PetDtos.PetResponse> listMine(UUID ownerId) {
        return pets.findAllByOwnerIdOrderByCreatedAtAsc(ownerId).stream().map(p -> toResponse(p, ownerId)).toList();
    }

    /** Mascotas de otra persona: solo si es una amistad (o la propia persona). */
    @Transactional(readOnly = true)
    public List<PetDtos.PetResponse> listOf(UUID ownerId, UUID viewerId) {
        if (!friendships.canSee(viewerId, ownerId)) {
            throw ApiException.notFound("user_not_found", "Perfil no disponible.");
        }
        return pets.findAllByOwnerIdOrderByCreatedAtAsc(ownerId).stream().map(p -> toResponse(p, viewerId)).toList();
    }

    @Transactional(readOnly = true)
    public PetDtos.PetResponse get(UUID petId, UUID viewerId) {
        return toResponse(visiblePet(petId, viewerId), viewerId);
    }

    @Transactional(readOnly = true)
    public Pet visiblePet(UUID petId, UUID viewerId) {
        Pet pet = pets.findById(petId).orElseThrow(PetService::notFound);
        if (!friendships.canSee(viewerId, pet.getOwnerId())) {
            throw notFound();
        }
        return pet;
    }

    @Transactional
    public PetDtos.PetResponse create(UUID ownerId, PetDtos.PetRequest request) {
        if (pets.countByOwnerId(ownerId) >= MAX_PETS_PER_USER) {
            throw ApiException.conflict("pet_limit", "Has alcanzado el máximo de mascotas.");
        }
        Pet pet = new Pet(ownerId, clock.instant());
        apply(pet, ownerId, request);
        return toResponse(pets.save(pet), ownerId);
    }

    @Transactional
    public PetDtos.PetResponse update(UUID ownerId, UUID petId, PetDtos.PetRequest request) {
        Pet pet = owned(petId, ownerId);
        UUID previousPhoto = pet.getPhotoMediaId();
        apply(pet, ownerId, request);
        if (previousPhoto != null && !previousPhoto.equals(pet.getPhotoMediaId())) {
            pets.flush();
            media.delete(previousPhoto);
        }
        return toResponse(pet, ownerId);
    }

    @Transactional
    public void delete(UUID ownerId, UUID petId) {
        Pet pet = owned(petId, ownerId);
        UUID photo = pet.getPhotoMediaId();
        pets.delete(pet);
        pets.flush();
        if (photo != null) {
            media.delete(photo);
        }
    }

    /** Verifica que todas las mascotas existen y pertenecen a la persona. */
    @Transactional(readOnly = true)
    public void requireAllOwned(UUID ownerId, Collection<UUID> petIds) {
        List<Pet> found = pets.findAllByIdIn(petIds);
        if (found.size() != new LinkedHashSet<>(petIds).size()
                || found.stream().anyMatch(p -> !p.getOwnerId().equals(ownerId))) {
            throw ApiException.badRequest("invalid_pets", "Elige solo entre tus mascotas.");
        }
    }

    @Transactional(readOnly = true)
    public Map<UUID, PetDtos.PetSummary> summaries(Collection<UUID> petIds) {
        if (petIds.isEmpty()) {
            return Map.of();
        }
        return pets.findAllByIdIn(petIds).stream()
                .map(p -> new PetDtos.PetSummary(p.getId(), p.getName(), p.getSpecies().name(),
                        MediaUrls.thumbnail(p.getPhotoMediaId())))
                .collect(Collectors.toMap(PetDtos.PetSummary::id, Function.identity()));
    }

    private void apply(Pet pet, UUID ownerId, PetDtos.PetRequest r) {
        UUID photo = r.photoMediaId();
        if (photo != null && !photo.equals(pet.getPhotoMediaId())) {
            media.requireOwned(photo, ownerId, MediaAsset.Purpose.PET_PHOTO);
        }
        Set<String> tags = new LinkedHashSet<>();
        if (r.tags() != null) {
            r.tags().stream().map(String::trim).filter(t -> !t.isEmpty()).forEach(tags::add);
        }
        pet.update(r.name().trim(), r.species(), blankToNull(r.breed()), r.birthDate(),
                r.gender(), blankToNull(r.description()), tags, photo, clock.instant());
    }

    private Pet owned(UUID petId, UUID ownerId) {
        return pets.findById(petId).filter(p -> p.getOwnerId().equals(ownerId)).orElseThrow(PetService::notFound);
    }

    private PetDtos.PetResponse toResponse(Pet p, UUID viewerId) {
        return new PetDtos.PetResponse(p.getId(), p.getOwnerId(), p.getName(), p.getSpecies().name(), p.getBreed(),
                p.getBirthDate(), p.getGender() == null ? null : p.getGender().name(), p.getDescription(),
                new ArrayList<>(p.getTags()), MediaUrls.full(p.getPhotoMediaId()),
                MediaUrls.thumbnail(p.getPhotoMediaId()), p.getOwnerId().equals(viewerId));
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static ApiException notFound() {
        return ApiException.notFound("pet_not_found", "Mascota no encontrada.");
    }
}
