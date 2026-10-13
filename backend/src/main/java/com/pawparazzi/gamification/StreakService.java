package com.pawparazzi.gamification;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * PawStreak: la fuente de verdad es el backend.
 * <p>Solo las publicaciones PawMoment cuentan como participación diaria (la Foto libre no suma
 * racha, ver Figma "Shutter / Tipos de publicación"). Publicar fuera de la ventana sigue contando.
 * Una participación por persona y día natural local, garantizada por bloqueo de fila sobre
 * paw_streaks y por la restricción única de daily_participations.</p>
 */
@Service
public class StreakService {

    /** Próximos hitos visibles. Coinciden con la cronología de diseño (3, 7, 14...) y las insignias futuras. */
    static final List<Integer> MILESTONES = List.of(3, 7, 14, 30, 60, 100, 365);

    public record StreakView(int current, int best, int totalDays, LocalDate lastParticipationDate,
                             boolean participatedToday, Integer nextMilestone, LocalDate today) {
    }

    private final PawStreakRepository streaks;
    private final DailyParticipationRepository participations;
    private final Clock clock;

    public StreakService(PawStreakRepository streaks, DailyParticipationRepository participations, Clock clock) {
        this.streaks = streaks;
        this.participations = participations;
        this.clock = clock;
    }

    @Transactional(propagation = Propagation.MANDATORY)
    public void initialize(UUID userId) {
        streaks.save(new PawStreak(userId, clock.instant()));
    }

    /**
     * Registra la participación del día. Idempotente: si ya existe para ese día devuelve false
     * sin modificar la racha. Debe ejecutarse dentro de la transacción que crea la publicación.
     */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean recordParticipation(UUID userId, LocalDate localDate, UUID postId, boolean onTime) {
        PawStreak streak = streaks.findForUpdate(userId)
                .orElseGet(() -> streaks.saveAndFlush(new PawStreak(userId, clock.instant())));
        if (participations.existsByUserIdAndLocalDate(userId, localDate)) {
            return false;
        }
        participations.save(new DailyParticipation(userId, localDate, postId, onTime, clock.instant()));
        streak.registerDay(localDate, clock.instant());
        return true;
    }

    @Transactional(readOnly = true)
    public Optional<UUID> participationPostId(UUID userId, LocalDate localDate) {
        return participations.findByUserIdAndLocalDate(userId, localDate).map(DailyParticipation::getPostId);
    }

    @Transactional(readOnly = true)
    public boolean hasParticipated(UUID userId, LocalDate localDate) {
        return participations.existsByUserIdAndLocalDate(userId, localDate);
    }

    @Transactional(readOnly = true)
    public StreakView view(UUID userId, ZoneId zone) {
        LocalDate today = LocalDate.now(clock.withZone(zone));
        PawStreak streak = streaks.findById(userId).orElseGet(() -> new PawStreak(userId, clock.instant()));
        int current = streak.effectiveCurrent(today);
        Integer next = MILESTONES.stream().filter(m -> m > current).findFirst().orElse(null);
        boolean participatedToday = participations.existsByUserIdAndLocalDate(userId, today);
        return new StreakView(current, streak.getBestStreak(), streak.getTotalDays(),
                streak.getLastParticipationDate(), participatedToday, next, today);
    }
}
