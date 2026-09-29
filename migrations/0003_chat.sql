CREATE TABLE IF NOT EXISTS chat_threads (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id),
  title TEXT NOT NULL DEFAULT 'Nuevo chat',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS chat_turns (
  id TEXT PRIMARY KEY,
  thread_id TEXT NOT NULL REFERENCES chat_threads(id),
  request_id TEXT NOT NULL UNIQUE,
  user_text TEXT NOT NULL,
  assistant_text TEXT NOT NULL,
  source TEXT NOT NULL CHECK(source IN ('gemini', 'base')),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_turns_thread ON chat_turns(thread_id, created_at);
