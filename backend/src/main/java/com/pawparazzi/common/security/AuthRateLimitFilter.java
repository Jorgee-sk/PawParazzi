package com.pawparazzi.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pawparazzi.common.config.AppProperties;
import com.pawparazzi.common.error.ApiError;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Clock;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Límite de frecuencia simple (ventana fija por minuto e IP) para registro, login y refresh.
 * Es en memoria: suficiente para una instancia del monolito; si se escala horizontalmente
 * habrá que moverlo a un almacén compartido.
 */
@Component
public class AuthRateLimitFilter extends OncePerRequestFilter {

    private final int limitPerMinute;
    private final Clock clock;
    private final ObjectMapper objectMapper;
    private final Map<String, Window> windows = new ConcurrentHashMap<>();

    public AuthRateLimitFilter(AppProperties props, Clock clock, ObjectMapper objectMapper) {
        this.limitPerMinute = props.rateLimit().authRequestsPerMinute();
        this.clock = clock;
        this.objectMapper = objectMapper;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !("POST".equals(request.getMethod()) && request.getRequestURI().startsWith("/api/v1/auth/"));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long minute = clock.millis() / 60_000;
        String key = request.getRemoteAddr();
        Window window = windows.compute(key, (k, w) -> (w == null || w.minute != minute) ? new Window(minute) : w);
        if (window.count.incrementAndGet() > limitPerMinute) {
            response.setHeader("Retry-After", "60");
            SecurityConfig.writeError(response, objectMapper, 429,
                    ApiError.of("rate_limited", "Demasiados intentos. Espera un minuto y vuelve a probar."));
            return;
        }
        if (windows.size() > 10_000) {
            windows.entrySet().removeIf(e -> e.getValue().minute != minute);
        }
        chain.doFilter(request, response);
    }

    private static final class Window {
        final long minute;
        final AtomicInteger count = new AtomicInteger();

        Window(long minute) {
            this.minute = minute;
        }
    }
}
