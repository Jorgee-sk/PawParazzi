-- Publicaciones: PawMoment (participación diaria) y Caza libre (PawParazzi Mode).
CREATE TABLE posts (
    id                 UUID PRIMARY KEY,
    author_id          UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    type               VARCHAR(20) NOT NULL,
    media_id           UUID NOT NULL REFERENCES media_assets (id),
    caption            VARCHAR(500),
    local_date         DATE NOT NULL,
    on_time            BOOLEAN,
    client_request_id  VARCHAR(64) NOT NULL,
    created_at         TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at         TIMESTAMP WITH TIME ZONE NOT NULL,
    -- Idempotencia frente a reintentos de red.
    CONSTRAINT uq_posts_client_request UNIQUE (author_id, client_request_id),
    -- Una imagen solo puede pertenecer a una publicación.
    CONSTRAINT uq_posts_media UNIQUE (media_id)
);
-- Paginación por cursor (created_at, id) del feed.
CREATE INDEX ix_posts_author_created ON posts (author_id, created_at DESC, id DESC);

-- Mascotas que aparecen en cada publicación (sin duplicar datos de perfil).
CREATE TABLE post_pets (
    post_id  UUID NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    pet_id   UUID NOT NULL REFERENCES pets (id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, pet_id)
);
CREATE INDEX ix_post_pets_pet ON post_pets (pet_id);

-- Categorías manuales (Descanso, Juego, Exterior, Travesuras, ...).
CREATE TABLE post_tags (
    post_id  UUID NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    tag      VARCHAR(30) NOT NULL,
    PRIMARY KEY (post_id, tag)
);

-- Una participación válida por persona y día natural local. Fuente de verdad de la racha.
CREATE TABLE daily_participations (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    local_date  DATE NOT NULL,
    post_id     UUID REFERENCES posts (id) ON DELETE SET NULL,
    on_time     BOOLEAN NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_daily_participation UNIQUE (user_id, local_date)
);

CREATE TABLE paw_streaks (
    user_id                  UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    current_streak           INTEGER NOT NULL,
    best_streak              INTEGER NOT NULL,
    total_days               INTEGER NOT NULL,
    last_participation_date  DATE,
    updated_at               TIMESTAMP WITH TIME ZONE NOT NULL
);
