CREATE TABLE comments (
    id          UUID PRIMARY KEY,
    post_id     UUID NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    author_id   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    body        VARCHAR(500) NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE INDEX ix_comments_post_created ON comments (post_id, created_at, id);
