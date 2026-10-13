package com.pawparazzi.safety;

import com.pawparazzi.comments.Comment;
import com.pawparazzi.comments.CommentRepository;
import com.pawparazzi.common.error.ApiException;
import com.pawparazzi.moments.PostService;
import com.pawparazzi.users.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reportes de contenido. Se puede reportar una publicación o un comentario que la persona puede ver,
 * o a otra persona. Reportar dos veces lo mismo no crea duplicados. Los reportes quedan en estado
 * OPEN para revisión humana; todavía no hay panel de administración (ver README).
 */
@Service
public class ReportService {

    public record ReportView(UUID id, String status, Instant createdAt) {
    }

    private final ReportRepository reports;
    private final PostService posts;
    private final CommentRepository comments;
    private final UserRepository users;
    private final Clock clock;

    public ReportService(ReportRepository reports, PostService posts, CommentRepository comments,
                         UserRepository users, Clock clock) {
        this.reports = reports;
        this.posts = posts;
        this.comments = comments;
        this.users = users;
        this.clock = clock;
    }

    @Transactional
    public ReportView report(UUID reporterId, Report.TargetType type, UUID targetId, Report.Reason reason,
                             String details) {
        UUID reportedUserId = switch (type) {
            case POST -> posts.requireVisible(targetId, reporterId).getAuthorId();
            case COMMENT -> {
                Comment comment = comments.findById(targetId)
                        .orElseThrow(() -> ApiException.notFound("comment_not_found", "Comentario no encontrado."));
                posts.requireVisible(comment.getPostId(), reporterId);
                yield comment.getAuthorId();
            }
            case USER -> {
                if (!users.existsById(targetId)) {
                    throw ApiException.notFound("user_not_found", "No encontramos a esa persona.");
                }
                yield targetId;
            }
        };
        if (reportedUserId.equals(reporterId)) {
            throw ApiException.badRequest("self_report", "No puedes reportar tu propio contenido.");
        }
        Report report = reports.findByReporterIdAndTargetTypeAndTargetId(reporterId, type, targetId)
                .orElseGet(() -> reports.save(new Report(reporterId, type, targetId, reportedUserId, reason,
                        details == null || details.isBlank() ? null : details.trim(), clock.instant())));
        return new ReportView(report.getId(), report.getStatus().name(), report.getCreatedAt());
    }
}
