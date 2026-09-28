CREATE TABLE IF NOT EXISTS availability_checks (
  product_id TEXT PRIMARY KEY REFERENCES products(id),
  checked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
