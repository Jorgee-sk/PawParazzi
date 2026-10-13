package com.pawparazzi.gamification;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PawStreakTest {

    private static final Instant NOW = Instant.parse("2026-10-12T10:00:00Z");
    private static final LocalDate DAY = LocalDate.of(2026, 10, 12);

    @Test
    void consecutiveDaysIncreaseStreakAndBest() {
        PawStreak s = new PawStreak(UUID.randomUUID(), NOW);
        s.registerDay(DAY, NOW);
        s.registerDay(DAY.plusDays(1), NOW);
        s.registerDay(DAY.plusDays(2), NOW);

        assertThat(s.getCurrentStreak()).isEqualTo(3);
        assertThat(s.getBestStreak()).isEqualTo(3);
        assertThat(s.getTotalDays()).isEqualTo(3);
    }

    @Test
    void gapRestartsStreakButKeepsBest() {
        PawStreak s = new PawStreak(UUID.randomUUID(), NOW);
        s.registerDay(DAY, NOW);
        s.registerDay(DAY.plusDays(1), NOW);
        s.registerDay(DAY.plusDays(3), NOW);

        assertThat(s.getCurrentStreak()).isEqualTo(1);
        assertThat(s.getBestStreak()).isEqualTo(2);
        assertThat(s.getTotalDays()).isEqualTo(3);
    }

    @Test
    void earlierDateCountsAsDayWithoutTouchingCurrentStreak() {
        PawStreak s = new PawStreak(UUID.randomUUID(), NOW);
        s.registerDay(DAY, NOW);
        s.registerDay(DAY.plusDays(1), NOW);
        // Cambio de zona horaria hacia atrás: llega una fecha anterior a la última.
        s.registerDay(DAY.minusDays(1), NOW);

        assertThat(s.getCurrentStreak()).isEqualTo(2);
        assertThat(s.getLastParticipationDate()).isEqualTo(DAY.plusDays(1));
        assertThat(s.getTotalDays()).isEqualTo(3);
    }

    @Test
    void effectiveStreakIsZeroWhenYesterdayWasMissed() {
        PawStreak s = new PawStreak(UUID.randomUUID(), NOW);
        s.registerDay(DAY, NOW);

        assertThat(s.effectiveCurrent(DAY)).isEqualTo(1);
        assertThat(s.effectiveCurrent(DAY.plusDays(1))).isEqualTo(1); // aún puede participar hoy
        assertThat(s.effectiveCurrent(DAY.plusDays(2))).isZero();     // interrumpida
        assertThat(new PawStreak(UUID.randomUUID(), NOW).effectiveCurrent(DAY)).isZero();
    }
}
