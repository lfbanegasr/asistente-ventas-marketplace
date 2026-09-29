-- Migración 0004: Campo de visibilidad/estado activo en productos
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
