package com.pawparazzi.moments;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class PawMomentWindowTest {

    private final PawMomentWindow window =
            new PawMomentWindow(LocalTime.of(10, 0), LocalTime.of(20, 0), Duration.ofMinutes(30));
    private final ZoneId madrid = ZoneId.of("Europe/Madrid");

    @Test
    void startIsDeterministicAndWithinConfiguredRange() {
        Set<LocalTime> starts = new HashSet<>();
        for (int i = 0; i < 365; i++) {
            LocalDate date = LocalDate.of(2026, 1, 1).plusDays(i);
            var w = window.forDate(date, madrid);
            LocalTime start = w.start().toLocalTime();
            assertThat(start).isBetween(LocalTime.of(10, 0), LocalTime.of(20, 0));
            assertThat(Duration.between(w.start(), w.end())).isEqualTo(Duration.ofMinutes(30));
            assertThat(window.forDate(date, madrid)).isEqualTo(w);
            starts.add(start);
        }
        // La hora varía entre días (no es siempre la misma).
        assertThat(starts.size()).isGreaterThan(100);
    }

    @Test
    void statusDistinguishesBeforeDuringAndAfter() {
        var w = window.forDate(LocalDate.of(2026, 10, 12), madrid);

        assertThat(w.statusAt(w.start().toInstant().minusSeconds(1))).isEqualTo(PawMomentWindow.Status.UPCOMING);
        assertThat(w.statusAt(w.start().toInstant())).isEqualTo(PawMomentWindow.Status.OPEN);
        assertThat(w.statusAt(w.end().toInstant())).isEqualTo(PawMomentWindow.Status.LATE);
        assertThat(w.contains(w.start().toInstant().plusSeconds(60))).isTrue();
        assertThat(w.contains(w.end().toInstant().plusSeconds(60))).isFalse();
    }
}
