package com.pawparazzi.reactions;

import com.pawparazzi.moments.PostDtos;
import com.pawparazzi.moments.PostService;
import java.time.Clock;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class ReactionService {

    private final ReactionRepository reactions;
    private final PostService posts;
    private final TransactionTemplate tx;
    private final Clock clock;

    public ReactionService(ReactionRepository reactions, PostService posts, PlatformTransactionManager txManager,
                           Clock clock) {
        this.reactions = reactions;
        this.posts = posts;
        this.tx = new TransactionTemplate(txManager);
        this.clock = clock;
    }

    /** Idempotente: reaccionar dos veces deja una sola reacción. */
    public PostDtos.ReactionSummary react(UUID userId, UUID postId) {
        try {
            tx.executeWithoutResult(s -> {
                posts.requireVisible(postId, userId);
                if (!reactions.existsByPostIdAndUserId(postId, userId)) {
                    reactions.saveAndFlush(new Reaction(postId, userId, clock.instant()));
                }
            });
        } catch (DataIntegrityViolationException ignored) {
            // Doble toque concurrente: la otra petición ya creó la reacción.
        }
        return summary(userId, postId);
    }

    @Transactional
    public PostDtos.ReactionSummary unreact(UUID userId, UUID postId) {
        posts.requireVisible(postId, userId);
        reactions.deleteByPostIdAndUserId(postId, userId);
        return summary(userId, postId);
    }

    private PostDtos.ReactionSummary summary(UUID userId, UUID postId) {
        return tx.execute(s -> {
            long count = reactions.countByPostIds(List.of(postId)).stream()
                    .mapToLong(ReactionRepository.PostCount::getTotal).sum();
            return new PostDtos.ReactionSummary(count, reactions.existsByPostIdAndUserId(postId, userId));
        });
    }
}
