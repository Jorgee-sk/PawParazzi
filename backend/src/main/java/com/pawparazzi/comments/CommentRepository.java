package com.pawparazzi.comments;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface CommentRepository extends JpaRepository<Comment, UUID> {

    interface PostCount {
        UUID getPostId();

        long getTotal();
    }

    /** Del más antiguo al más reciente, como una conversación. */
    @Query("select c from Comment c where c.postId = :postId order by c.createdAt asc, c.id asc")
    List<Comment> firstPage(@Param("postId") UUID postId, Pageable pageable);

    @Query("select c from Comment c where c.postId = :postId"
            + " and (c.createdAt > :cursorAt or (c.createdAt = :cursorAt and c.id > :cursorId))"
            + " order by c.createdAt asc, c.id asc")
    List<Comment> pageAfter(@Param("postId") UUID postId, @Param("cursorAt") Instant cursorAt,
                            @Param("cursorId") UUID cursorId, Pageable pageable);

    @Query("select c.postId as postId, count(c) as total from Comment c where c.postId in :postIds group by c.postId")
    List<PostCount> countByPostIds(@Param("postIds") Collection<UUID> postIds);
}
