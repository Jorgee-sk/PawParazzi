package com.pawparazzi.pets;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PetRepository extends JpaRepository<Pet, UUID> {

    List<Pet> findAllByOwnerIdOrderByCreatedAtAsc(UUID ownerId);

    List<Pet> findAllByIdIn(Collection<UUID> ids);

    long countByOwnerId(UUID ownerId);
}
