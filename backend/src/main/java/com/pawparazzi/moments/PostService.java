package com.pawparazzi.moments;

import com.pawparazzi.common.TimeZones;
import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.friendships.FriendshipService;
import com.pawparazzi.gamification.StreakService;
import com.pawparazzi.media.MediaAsset;
import com.pawparazzi.media.MediaService;
import com.pawparazzi.pets.PetService;
import com.pawparazzi.users.User;
import com.pawparazzi.users.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class PostService {

    static final int DEFAULT_PAGE_SIZE = 20;
    static final int MAX_PAGE_SIZE = 50;

    private final PostRepository posts;
    private final PostAssembler assembler;
    private final UserRepository users;
    private final MediaService media;
    private final PetService pets;
    private final FriendshipService friendships;
    private final StreakService streaks;
    private final PawMomentWindow window;
    private final TransactionTemplate tx;
    private final Clock clock;

    public PostService(PostRepository posts, PostAssembler assembler, UserRepository users, MediaService media,
                       PetService pets, FriendshipService friendships, StreakService streaks,
                       PawMomentWindow window, PlatformTransactionManager txManager, Clock clock) {
        this.posts = posts;
        this.assembler = assembler;
        this.users = users;
        this.media = media;
        this.pets = pets;
        this.friendships = friendships;
        this.streaks = streaks;
        this.window = window;
        this.tx = new TransactionTemplate(txManager);
        this.clock = clock;
    }

    /**
     * Publica una foto. Idempotente por {@code clientRequestId}: un reintento de red devuelve la
     * publicación ya creada sin duplicarla ni volver a contar la racha. La ventana de PawMoment
     * nunca bloquea: fuera de ella la publicación se marca como {@code onTime=false} y sigue contando.
     */
    public PostDtos.CreatePostResponse create(UUID userId, PostDtos.CreatePostRequest request) {
        try {
            return tx.execute(status -> createInTransaction(userId, request));
        } catch (DataIntegrityViolationException e) {
            // Carrera entre dos reintentos simultáneos: el otro ganó; devolvemos su resultado.
            return tx.execute(status -> posts.findByAuthorIdAndClientRequestId(userId, request.clientRequestId())
                    .map(p -> new PostDtos.CreatePostResponse(assembler.toView(p, userId), false, true))
                    .orElseThrow(() -> e));
        }
    }

    private PostDtos.CreatePostResponse createInTransaction(UUID userId, PostDtos.CreatePostRequest r) {
        var existing = posts.findByAuthorIdAndClientRequestId(userId, r.clientRequestId());
        if (existing.isPresent()) {
            return new PostDtos.CreatePostResponse(assembler.toView(existing.get(), userId), false, true);
        }
        User author = users.findById(userId)
                .orElseThrow(() -> ApiException.unauthorized("unauthorized", "Inicia sesión para continuar."));
        ZoneId zone = TimeZones.parseOrUtc(author.getTimeZone());
        // PostgreSQL guarda microsegundos: truncamos para que los cursores sean exactos.
        Instant now = clock.instant().truncatedTo(ChronoUnit.MICROS);
        LocalDate localDate = LocalDate.ofInstant(now, zone);

        media.requireOwned(r.mediaId(), userId, MediaAsset.Purpose.POST);
        if (posts.existsByMediaId(r.mediaId())) {
            throw ApiException.conflict("media_in_use", "Esta foto ya está publicada.");
        }
        Set<UUID> petIds = new LinkedHashSet<>(r.petIds());
        pets.requireAllOwned(userId, petIds);

        Boolean onTime = null;
        if (r.type() == Post.Type.PAW_MOMENT) {
            onTime = window.forDate(localDate, zone).contains(now);
            if (streaks.hasParticipated(userId, localDate)) {
                throw ApiException.conflict("already_participated",
                        "Ya compartiste tu PawMoment de hoy. Puedes publicar esta foto como Foto libre.");
            }
        }
        Post post = posts.saveAndFlush(new Post(userId, r.type(), r.mediaId(), blankToNull(r.caption()), localDate,
                onTime, r.clientRequestId(), petIds, tags(r.tags()), now));

        boolean counted = false;
        if (r.type() == Post.Type.PAW_MOMENT) {
            counted = streaks.recordParticipation(userId, localDate, post.getId(), onTime);
            if (!counted) {
                // Otra publicación PawMoment concurrente ganó la participación del día.
                throw ApiException.conflict("already_participated",
                        "Ya compartiste tu PawMoment de hoy. Puedes publicar esta foto como Foto libre.");
            }
        }
        return new PostDtos.CreatePostResponse(assembler.toView(post, userId), counted, false);
    }

    @Transactional(readOnly = true)
    public PostDtos.PostView get(UUID postId, UUID viewerId) {
        return assembler.toView(requireVisible(postId, viewerId), viewerId);
    }

    @Transactional(readOnly = true)
    public Post requireVisible(UUID postId, UUID viewerId) {
        Post post = posts.findById(postId).orElseThrow(PostService::notFound);
        if (!friendships.canSee(viewerId, post.getAuthorId())) {
            throw notFound();
        }
        return post;
    }

    @Transactional
    public PostDtos.PostView update(UUID userId, UUID postId, PostDtos.UpdatePostRequest r) {
        Post post = owned(postId, userId);
        Set<UUID> petIds = new LinkedHashSet<>(r.petIds());
        pets.requireAllOwned(userId, petIds);
        post.edit(blankToNull(r.caption()), petIds, tags(r.tags()), clock.instant());
        posts.flush();
        return assembler.toView(post, userId);
    }

    /**
     * Elimina la publicación y su imagen. Si era un PawMoment, la participación del día se conserva
     * (la persona sí participó); la referencia a la publicación queda a null.
     */
    @Transactional
    public void delete(UUID userId, UUID postId) {
        Post post = owned(postId, userId);
        UUID mediaId = post.getMediaId();
        posts.delete(post);
        posts.flush();
        media.delete(mediaId);
    }

    @Transactional(readOnly = true)
    public PostDtos.PageResponse<PostDtos.PostView> friendsFeed(UUID viewerId, String cursor, Integer limit) {
        int size = pageSize(limit);
        PageRequest page = PageRequest.of(0, size + 1);
        List<Post> found;
        if (cursor == null || cursor.isBlank()) {
            found = posts.friendsFeedFirst(viewerId, page);
        } else {
            PostAssembler.Cursor c = PostAssembler.decodeCursor(cursor);
            found = posts.friendsFeedAfter(viewerId, c.createdAt(), c.id(), page);
        }
        return page(found, size, viewerId);
    }

    @Transactional(readOnly = true)
    public PostDtos.PageResponse<PostDtos.PostView> petPosts(UUID petId, UUID viewerId, String cursor, Integer limit) {
        pets.visiblePet(petId, viewerId);
        int size = pageSize(limit);
        PageRequest page = PageRequest.of(0, size + 1);
        List<Post> found;
        if (cursor == null || cursor.isBlank()) {
            found = posts.byPetFirst(petId, page);
        } else {
            PostAssembler.Cursor c = PostAssembler.decodeCursor(cursor);
            found = posts.byPetAfter(petId, c.createdAt(), c.id(), page);
        }
        return page(found, size, viewerId);
    }

    @Transactional(readOnly = true)
    public PostDtos.TodayMoment today(UUID userId) {
        User user = users.findById(userId)
                .orElseThrow(() -> ApiException.unauthorized("unauthorized", "Inicia sesión para continuar."));
        ZoneId zone = TimeZones.parseOrUtc(user.getTimeZone());
        Instant now = clock.instant();
        LocalDate today = LocalDate.ofInstant(now, zone);
        PawMomentWindow.DailyWindow w = window.forDate(today, zone);
        var participation = streaks.participationPostId(userId, today);
        boolean participated = streaks.hasParticipated(userId, today);
        return new PostDtos.TodayMoment(today, w.start().toInstant(), w.end().toInstant(),
                w.statusAt(now).name(), participated, participation.orElse(null));
    }

    private PostDtos.PageResponse<PostDtos.PostView> page(List<Post> found, int size, UUID viewerId) {
        boolean hasMore = found.size() > size;
        List<Post> items = hasMore ? found.subList(0, size) : found;
        String next = hasMore ? PostAssembler.encodeCursor(items.getLast()) : null;
        return new PostDtos.PageResponse<>(assembler.toViews(items, viewerId), next);
    }

    private Post owned(UUID postId, UUID userId) {
        return posts.findById(postId).filter(p -> p.getAuthorId().equals(userId)).orElseThrow(PostService::notFound);
    }

    private static int pageSize(Integer limit) {
        if (limit == null) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.max(1, Math.min(MAX_PAGE_SIZE, limit));
    }

    private static Set<Post.Tag> tags(List<Post.Tag> tags) {
        return tags == null ? Set.of() : new LinkedHashSet<>(tags);
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static ApiException notFound() {
        return ApiException.notFound("post_not_found", "Publicación no encontrada.");
    }
}
