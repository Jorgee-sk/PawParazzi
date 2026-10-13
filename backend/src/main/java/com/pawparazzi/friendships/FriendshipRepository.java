package com.pawparazzi.friendships;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FriendshipRepository extends JpaRepository<Friendship, UUID> {

    Optional<Friendship> findByUserLowIdAndUserHighId(UUID low, UUID high);

    boolean existsByUserLowIdAndUserHighId(UUID low, UUID high);

    @Query("select f from Friendship f where f.userLowId = :userId or f.userHighId = :userId order by f.createdAt desc")
    List<Friendship> findAllOf(@Param("userId") UUID userId);
}
