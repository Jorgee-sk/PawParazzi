-- Bloqueos: quien bloquea deja de ser amistad de la otra persona y esta no puede volver a enviarle solicitudes.
CREATE TABLE blocks (
    id          UUID PRIMARY KEY,
    blocker_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_blocks_pair UNIQUE (blocker_id, blocked_id),
    CONSTRAINT ck_blocks_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX ix_blocks_blocked ON blocks (blocked_id);

-- Reportes de contenido para revisión humana.
-- target_id no tiene clave foránea a propósito: el reporte debe sobrevivir aunque se borre el contenido.
-- reported_user_id guarda de quién era el contenido en el momento del reporte.
CREATE TABLE reports (
    id                UUID PRIMARY KEY,
    reporter_id       UUID REFERENCES users (id) ON DELETE SET NULL,
    target_type       VARCHAR(20) NOT NULL,
    target_id         UUID NOT NULL,
    reported_user_id  UUID REFERENCES users (id) ON DELETE SET NULL,
    reason            VARCHAR(30) NOT NULL,
    details           VARCHAR(500),
    status            VARCHAR(20) NOT NULL,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_reports_reporter_target UNIQUE (reporter_id, target_type, target_id)
);
CREATE INDEX ix_reports_status_created ON reports (status, created_at);
