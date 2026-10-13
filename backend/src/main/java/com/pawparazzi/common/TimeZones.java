package com.pawparazzi.common;

import java.time.DateTimeException;
import java.time.ZoneId;
import java.time.ZoneOffset;

public final class TimeZones {

    private TimeZones() {
    }

    /** Valida un identificador IANA (p. ej. "Europe/Madrid"). */
    public static boolean isValid(String zone) {
        if (zone == null || zone.isBlank()) {
            return false;
        }
        try {
            ZoneId.of(zone);
            return true;
        } catch (DateTimeException e) {
            return false;
        }
    }

    public static ZoneId parseOrUtc(String zone) {
        return isValid(zone) ? ZoneId.of(zone) : ZoneOffset.UTC;
    }
}
