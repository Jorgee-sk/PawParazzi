-- Resultado de la revisión automática de cada imagen guardada.
-- Las rechazadas no llegan a guardarse, así que aquí solo hay APPROVED o UNCHECKED
-- (sin proveedor configurado, o el proveedor falló y la política permite aceptar).
ALTER TABLE media_assets ADD COLUMN moderation_status VARCHAR(20) DEFAULT 'UNCHECKED' NOT NULL;
ALTER TABLE media_assets ADD COLUMN moderation_provider VARCHAR(80);
