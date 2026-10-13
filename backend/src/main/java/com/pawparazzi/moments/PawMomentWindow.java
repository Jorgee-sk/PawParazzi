package com.pawparazzi.moments;

import com.pawparazzi.common.config.AppProperties;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

/**
 * Calcula la ventana diaria de PawMoment.
 * <p>La hora de inicio es determinista por fecha (mismo instante local para todo el mundo ese día),
 * pseudoaleatoria entre {@code earliestStart} y {@code latestStart}, y la ventana dura
 * {@code windowDuration}. La ventana es solo informativa: publicar fuera de ella está permitido
 * y sigue contando para la racha.</p>
 */
@Component
public class PawMomentWindow {

    public enum Status { UPCOMING, OPEN, LATE }

    public record DailyWindow(LocalDate date, ZonedDateTime start, ZonedDateTime end) {

        public Status statusAt(Instant now) {
            if (now.isBefore(start.toInstant())) {
                return Status.UPCOMING;
            }
            return now.isBefore(end.toInstant()) ? Status.OPEN : Status.LATE;
        }

        public boolean contains(Instant instant) {
            return !instant.isBefore(start.toInstant()) && instant.isBefore(end.toInstant());
        }
    }

    private final LocalTime earliest;
    private final LocalTime latest;
    private final Duration duration;

    @Autowired
    public PawMomentWindow(AppProperties props) {
        this(props.pawmoment().earliestStart(), props.pawmoment().latestStart(), props.pawmoment().windowDuration());
    }

    PawMomentWindow(LocalTime earliest, LocalTime latest, Duration duration) {
        if (!latest.isAfter(earliest)) {
            throw new IllegalArgumentException("latest-start debe ser posterior a earliest-start");
        }
        this.earliest = earliest;
        this.latest = latest;
        this.duration = duration;
    }

    public DailyWindow forDate(LocalDate date, ZoneId zone) {
        long rangeMinutes = Duration.between(earliest, latest).toMinutes();
        long offset = Math.floorMod(mix(date.toEpochDay()), rangeMinutes + 1);
        ZonedDateTime start = date.atTime(earliest.plusMinutes(offset)).atZone(zone);
        return new DailyWindow(date, start, start.plus(duration));
    }

    /** SplitMix64: dispersión estable y reproducible a partir del día. */
    static long mix(long seed) {
        long z = seed + 0x9E3779B97F4A7C15L;
        z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
        z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
        return z ^ (z >>> 31);
    }
}
