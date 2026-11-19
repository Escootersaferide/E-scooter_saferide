PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    phone TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    expires_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions (expires_at);

CREATE TABLE IF NOT EXISTS ride_assessments (
    id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('qualification', 'order')),
    questions TEXT,
    created_at INTEGER NOT NULL,
    completed_at INTEGER,
    passed INTEGER CHECK (passed IN (0, 1)),
    readiness_ok INTEGER CHECK (readiness_ok IN (0, 1)),
    score INTEGER,
    total INTEGER
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_ride_assessments_pending
    ON ride_assessments (user_id, kind) WHERE completed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ride_assessments_history
    ON ride_assessments (user_id, kind, completed_at DESC);
