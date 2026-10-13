package com.pawparazzi.moments;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Las consultas paginadas usan cursor (createdAt, id) y tienen variante de primera página y de
 * página siguiente para no depender de parámetros nulos (problemático en PostgreSQL).
 */
public interface PostRepository extends JpaRepository<Post, UUID> {

    Optional<Post> findByAuthorIdAndClientRequestId(UUID authorId, String clientRequestId);

    boolean existsByMediaId(UUID mediaId);

    String VISIBLE_TO_VIEWER = """
            (p.authorId = :viewerId
             or p.authorId in (select f.userHighId from Friendship f where f.userLowId = :viewerId)
             or p.authorId in (select f.userLowId from Friendship f where f.userHighId = :viewerId))
            """;

    /** Feed de amigos: publicaciones propias y de amistades aceptadas. Visibilidad resuelta en servidor. */
    @Query("select p from Post p where " + VISIBLE_TO_VIEWER + " order by p.createdAt desc, p.id desc")
    List<Post> friendsFeedFirst(@Param("viewerId") UUID viewerId, Pageable pageable);

    @Query("select p from Post p where " + VISIBLE_TO_VIEWER
            + " and (p.createdAt < :cursorAt or (p.createdAt = :cursorAt and p.id < :cursorId))"
            + " order by p.createdAt desc, p.id desc")
    List<Post> friendsFeedAfter(@Param("viewerId") UUID viewerId, @Param("cursorAt") Instant cursorAt,
                                @Param("cursorId") UUID cursorId, Pageable pageable);

    /** Publicaciones en las que aparece una mascota (la visibilidad del dueño se comprueba antes). */
    @Query("select p from Post p join p.petIds pid where pid = :petId order by p.createdAt desc, p.id desc")
    List<Post> byPetFirst(@Param("petId") UUID petId, Pageable pageable);

    @Query("select p from Post p join p.petIds pid where pid = :petId"
            + " and (p.createdAt < :cursorAt or (p.createdAt = :cursorAt and p.id < :cursorId))"
            + " order by p.createdAt desc, p.id desc")
    List<Post> byPetAfter(@Param("petId") UUID petId, @Param("cursorAt") Instant cursorAt,
                          @Param("cursorId") UUID cursorId, Pageable pageable);
}
