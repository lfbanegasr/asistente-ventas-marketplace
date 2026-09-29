-- Migración inicial para PostgreSQL (Neon, Supabase, Render, Railway, etc.)

CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(100) PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  facts TEXT NOT NULL DEFAULT '',
  cost INTEGER NOT NULL CHECK (cost >= 0),
  price INTEGER NOT NULL CHECK (price >= 0),
  min_price INTEGER NOT NULL CHECK (min_price >= 0),
  availability VARCHAR(50) NOT NULL DEFAULT 'por_confirmar' CHECK (availability IN ('en_mano','proveedor_confirmado','por_confirmar')),
  available_units INTEGER NOT NULL DEFAULT 0 CHECK (available_units >= 0),
  ready_date VARCHAR(20) NOT NULL DEFAULT '',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS availability_checks (
  product_id VARCHAR(100) PRIMARY KEY REFERENCES products(id) ON DELETE CASCADE,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS leads (
  id VARCHAR(100) PRIMARY KEY,
  request_id VARCHAR(100) NOT NULL UNIQUE,
  alias VARCHAR(200) NOT NULL,
  channel VARCHAR(50) NOT NULL CHECK (channel IN ('Marketplace','WhatsApp','Otro')),
  product_id VARCHAR(100) NOT NULL REFERENCES products(id),
  status VARCHAR(50) NOT NULL DEFAULT 'consulta' CHECK (status IN ('consulta','interesado','confirmado','comprado','agendado','entregado','cancelado')),
  amount INTEGER NOT NULL CHECK (amount >= 0),
  actual_cost INTEGER NOT NULL CHECK (actual_cost >= 0),
  expenses INTEGER NOT NULL DEFAULT 0 CHECK (expenses >= 0),
  delivery_mode VARCHAR(50) NOT NULL DEFAULT 'por_definir' CHECK (delivery_mode IN ('por_definir','persona','yango')),
  delivery_place VARCHAR(300) NOT NULL DEFAULT '',
  delivery_at VARCHAR(50) NOT NULL DEFAULT '',
  paid INTEGER NOT NULL DEFAULT 0 CHECK (paid IN (0,1)),
  notes TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_leads_delivery ON leads(delivery_at);

CREATE TABLE IF NOT EXISTS chat_threads (
  id VARCHAR(100) PRIMARY KEY,
  product_id VARCHAR(100) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  title VARCHAR(300) NOT NULL DEFAULT 'Nuevo chat',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS chat_turns (
  id VARCHAR(100) PRIMARY KEY,
  thread_id VARCHAR(100) NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  request_id VARCHAR(100) NOT NULL UNIQUE,
  user_text TEXT NOT NULL,
  assistant_text TEXT NOT NULL,
  source VARCHAR(50) NOT NULL CHECK (source IN ('gemini', 'base')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_turns_thread ON chat_turns(thread_id, created_at);

CREATE TABLE IF NOT EXISTS ai_usage (
  day VARCHAR(20) PRIMARY KEY,
  count INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS auth_attempts (
  bucket VARCHAR(100) PRIMARY KEY,
  attempts INTEGER NOT NULL,
  reset_at BIGINT NOT NULL
);

INSERT INTO products (id, name, facts, cost, price, min_price) VALUES
('pb6010', 'Yesido PB6010', 'Caja indica 30.000 mAh, carga hasta 22,5 W, cables USB-C y Lightning integrados y pantalla de porcentaje. No prometer capacidad útil ni compatibilidad específica sin probar.', 98, 170, 170),
('pb225', 'Yesido PB225', 'Modelo compacto con zona de carga inalámbrica para teléfonos compatibles. No afirmar MagSafe, imanes, potencia ni capacidad real sin comprobar.', 110, 180, 180),
('kp5501', 'KNUP KP-5501TM', 'Combo de teclado completo con teclado numérico y mouse. Conexión USB por cable e iluminación según empaque. No afirmar que sea mecánico.', 85, 160, 150)
ON CONFLICT (id) DO NOTHING;
