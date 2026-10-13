package com.pawparazzi.reactions;

import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ReactionRepository extends JpaRepository<Reaction, UUID> {

    interface PostCount {
        UUID getPostId();

        long getTotal();
    }

    boolean existsByPostIdAndUserId(UUID postId, UUID userId);

    @Modifying
    @Query("delete from Reaction r where r.postId = :postId and r.userId = :userId")
    int deleteByPostIdAndUserId(@Param("postId") UUID postId, @Param("userId") UUID userId);

    @Query("select r.postId as postId, count(r) as total from Reaction r where r.postId in :postIds group by r.postId")
    List<PostCount> countByPostIds(@Param("postIds") Collection<UUID> postIds);

    @Query("select r.postId from Reaction r where r.userId = :userId and r.postId in :postIds")
    List<UUID> reactedPostIds(@Param("userId") UUID userId, @Param("postIds") Collection<UUID> postIds);
}
