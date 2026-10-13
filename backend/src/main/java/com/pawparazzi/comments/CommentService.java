package com.pawparazzi.comments;

import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.moments.Post;
import com.pawparazzi.moments.PostAssembler;
import com.pawparazzi.moments.PostDtos;
import com.pawparazzi.moments.PostService;
import com.pawparazzi.safety.BlockRepository;
import com.pawparazzi.users.UserDirectory;
import com.pawparazzi.users.UserDtos;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Comentarios de una publicación. Solo pueden leerlos y escribirlos quienes ven la publicación
 * (su autora y sus amistades). Puede borrar un comentario quien lo escribió o la autora de la
 * publicación, para poder retirar comentarios molestos de sus propias fotos. Los comentarios de personas
 * con las que hay un bloqueo no se muestran (el contador de la publicación sí los incluye).
 */
@Service
public class CommentService {

    static final int DEFAULT_PAGE_SIZE = 30;
    static final int MAX_PAGE_SIZE = 100;

    public record CommentView(UUID id, UUID postId, String body, Instant createdAt, UserDtos.UserSummary author,
                              boolean canDelete) {
    }

    private final CommentRepository comments;
    private final PostService posts;
    private final UserDirectory users;
    private final BlockRepository blocks;
    private final Clock clock;

    public CommentService(CommentRepository comments, PostService posts, UserDirectory users,
                          BlockRepository blocks, Clock clock) {
        this.comments = comments;
        this.posts = posts;
        this.users = users;
        this.blocks = blocks;
        this.clock = clock;
    }

    @Transactional
    public CommentView add(UUID userId, UUID postId, String body) {
        Post post = posts.requireVisible(postId, userId);
        String text = body.trim();
        if (text.isEmpty()) {
            throw ApiException.badRequest("validation_failed", "Escribe algo antes de enviar.");
        }
        Comment comment = comments.save(
                new Comment(postId, userId, text, clock.instant().truncatedTo(ChronoUnit.MICROS)));
        return views(List.of(comment), userId, post).getFirst();
    }

    @Transactional(readOnly = true)
    public PostDtos.PageResponse<CommentView> list(UUID userId, UUID postId, String cursor, Integer limit) {
        Post post = posts.requireVisible(postId, userId);
        int size = limit == null ? DEFAULT_PAGE_SIZE : Math.max(1, Math.min(MAX_PAGE_SIZE, limit));
        PageRequest page = PageRequest.of(0, size + 1);
        List<Comment> found;
        if (cursor == null || cursor.isBlank()) {
            found = comments.firstPage(postId, page);
        } else {
            PostAssembler.Cursor c = PostAssembler.decodeCursor(cursor);
            found = comments.pageAfter(postId, c.createdAt(), c.id(), page);
        }
        boolean hasMore = found.size() > size;
        List<Comment> items = hasMore ? found.subList(0, size) : found;
        String next = hasMore
                ? PostAssembler.encodeCursor(items.getLast().getCreatedAt(), items.getLast().getId())
                : null;
        // En publicaciones de terceros no se muestran los comentarios de personas bloqueadas (en cualquier
        // sentido). El cursor se calcula antes de filtrar para no saltarse páginas.
        Set<UUID> hidden = new HashSet<>(blocks.counterpartsOf(userId));
        List<Comment> visible = hidden.isEmpty() ? items
                : items.stream().filter(co -> !hidden.contains(co.getAuthorId())).toList();
        return new PostDtos.PageResponse<>(views(visible, userId, post), next);
    }

    @Transactional
    public void delete(UUID userId, UUID commentId) {
        Comment comment = comments.findById(commentId).orElseThrow(CommentService::notFound);
        // Si ya no ve la publicación (por ejemplo, dejaron de ser amigos) responde 404, como todo lo ajeno.
        Post post = posts.requireVisible(comment.getPostId(), userId);
        if (!canDelete(comment, post, userId)) {
            throw ApiException.forbidden("forbidden", "No puedes borrar este comentario.");
        }
        comments.delete(comment);
    }

    private List<CommentView> views(List<Comment> list, UUID viewerId, Post post) {
        Map<UUID, UserDtos.UserSummary> authors = users.summaries(
                list.stream().map(Comment::getAuthorId).collect(Collectors.toSet()));
        return list.stream().map(c -> new CommentView(c.getId(), c.getPostId(), c.getBody(), c.getCreatedAt(),
                authors.get(c.getAuthorId()), canDelete(c, post, viewerId))).toList();
    }

    private static boolean canDelete(Comment comment, Post post, UUID userId) {
        return comment.getAuthorId().equals(userId) || post.getAuthorId().equals(userId);
    }

    private static ApiException notFound() {
        return ApiException.notFound("comment_not_found", "Comentario no encontrado.");
    }
}
