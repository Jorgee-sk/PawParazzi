-- Metadatos de imágenes. Los bytes viven fuera de la base de datos (almacenamiento local o S3/MinIO).
CREATE TABLE media_assets (
    id             UUID PRIMARY KEY,
    owner_id       UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    purpose        VARCHAR(20)  NOT NULL,
    storage_key    VARCHAR(255) NOT NULL,
    thumbnail_key  VARCHAR(255) NOT NULL,
    content_type   VARCHAR(50)  NOT NULL,
    width          INTEGER NOT NULL,
    height         INTEGER NOT NULL,
    size_bytes     BIGINT  NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_media_assets_owner ON media_assets (owner_id);

ALTER TABLE users
    ADD CONSTRAINT fk_users_avatar_media FOREIGN KEY (avatar_media_id) REFERENCES media_assets (id) ON DELETE SET NULL;

CREATE TABLE pets (
    id              UUID PRIMARY KEY,
    owner_id        UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name            VARCHAR(40) NOT NULL,
    species         VARCHAR(20) NOT NULL,
    breed           VARCHAR(60),
    birth_date      DATE,
    gender          VARCHAR(20),
    description     VARCHAR(300),
    photo_media_id  UUID REFERENCES media_assets (id) ON DELETE SET NULL,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_pets_owner ON pets (owner_id);

-- Etiquetas elegidas por la persona (p. ej. "Curiosa", "Dormilona").
CREATE TABLE pet_tags (
    pet_id  UUID NOT NULL REFERENCES pets (id) ON DELETE CASCADE,
    tag     VARCHAR(30) NOT NULL,
    PRIMARY KEY (pet_id, tag)
);
