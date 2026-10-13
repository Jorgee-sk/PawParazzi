CREATE TABLE friend_requests (
    id            UUID PRIMARY KEY,
    requester_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    addressee_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status        VARCHAR(20) NOT NULL,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    responded_at  TIMESTAMP WITH TIME ZONE,
    CONSTRAINT ck_friend_requests_not_self CHECK (requester_id <> addressee_id)
);
CREATE INDEX ix_friend_requests_addressee ON friend_requests (addressee_id, status);
CREATE INDEX ix_friend_requests_requester ON friend_requests (requester_id, status);

-- Amistad simétrica guardada una sola vez con el par ordenado (low < high).
CREATE TABLE friendships (
    id            UUID PRIMARY KEY,
    user_low_id   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    user_high_id  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_friendships_pair UNIQUE (user_low_id, user_high_id),
    CONSTRAINT ck_friendships_order CHECK (user_low_id < user_high_id)
);
CREATE INDEX ix_friendships_high ON friendships (user_high_id);

-- "Cariños": una reacción por persona y publicación. No se convierten en puntos ni rankings.
CREATE TABLE reactions (
    id          UUID PRIMARY KEY,
    post_id     UUID NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT uq_reactions_post_user UNIQUE (post_id, user_id)
);
