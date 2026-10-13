package com.pawparazzi.gamification;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@Entity
@Table(name = "paw_streaks")
public class PawStreak {

    @Id
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "current_streak", nullable = false)
    private int currentStreak;

    @Column(name = "best_streak", nullable = false)
    private int bestStreak;

    @Column(name = "total_days", nullable = false)
    private int totalDays;

    @Column(name = "last_participation_date")
    private LocalDate lastParticipationDate;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected PawStreak() {
    }

    public PawStreak(UUID userId, Instant now) {
        this.userId = userId;
        this.updatedAt = now;
    }

    /**
     * Registra un día nuevo de participación. Debe llamarse una sola vez por día (lo garantiza
     * la tabla daily_participations). Reglas:
     * <ul>
     *   <li>Día consecutivo al último: la racha suma 1.</li>
     *   <li>Hueco de uno o más días (o primera vez): la racha vuelve a 1.</li>
     *   <li>Fecha anterior a la última (p. ej. cambio de zona horaria hacia atrás): cuenta como
     *       día participado pero no altera la racha actual.</li>
     * </ul>
     */
    void registerDay(LocalDate day, Instant now) {
        totalDays++;
        if (lastParticipationDate == null || day.isAfter(lastParticipationDate)) {
            if (lastParticipationDate != null && day.equals(lastParticipationDate.plusDays(1))) {
                currentStreak++;
            } else {
                currentStreak = 1;
            }
            lastParticipationDate = day;
            bestStreak = Math.max(bestStreak, currentStreak);
        }
        updatedAt = now;
    }

    /** Racha vigente vista desde {@code today}: si se saltó ayer, está interrumpida (0). */
    public int effectiveCurrent(LocalDate today) {
        if (lastParticipationDate == null) {
            return 0;
        }
        boolean alive = !lastParticipationDate.isBefore(today.minusDays(1));
        return alive ? currentStreak : 0;
    }

    public UUID getUserId() {
        return userId;
    }

    public int getCurrentStreak() {
        return currentStreak;
    }

    public int getBestStreak() {
        return bestStreak;
    }

    public int getTotalDays() {
        return totalDays;
    }

    public LocalDate getLastParticipationDate() {
        return lastParticipationDate;
    }
}
