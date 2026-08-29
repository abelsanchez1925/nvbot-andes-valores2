-- =========================================================
-- InvBot — Script de configuración para Supabase
-- Pega esto completo en: Supabase > SQL Editor > New query > Run
-- =========================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------- Tablas (igual al modelo del informe técnico, sección 5.1) ----------

CREATE TABLE IF NOT EXISTS clientes (
    id_cliente        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_completo   VARCHAR(150) NOT NULL,
    correo            VARCHAR(150) NOT NULL UNIQUE,
    telefono          VARCHAR(20)  NOT NULL,
    cedula            VARCHAR(20)  NOT NULL UNIQUE,
    perfil_riesgo     VARCHAR(20)  NOT NULL DEFAULT 'moderado'
                       CHECK (perfil_riesgo IN ('conservador','moderado','agresivo')),
    fecha_registro    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS cuentas (
    id_cuenta         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_cliente        UUID NOT NULL REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    numero_cuenta     VARCHAR(20) NOT NULL UNIQUE,
    saldo_disponible  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (saldo_disponible >= 0),
    saldo_custodia    NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (saldo_custodia >= 0),
    estado_cuenta     VARCHAR(15) NOT NULL DEFAULT 'activa'
                       CHECK (estado_cuenta IN ('activa','suspendida','cerrada')),
    fecha_apertura    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS catalogo_instrumentos (
    id_instrumento    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo_nemonico   VARCHAR(15) NOT NULL UNIQUE,
    nombre            VARCHAR(150) NOT NULL,
    tipo_instrumento  VARCHAR(20) NOT NULL
                       CHECK (tipo_instrumento IN ('accion','bono','obligacion','papel_comercial')),
    mercado           VARCHAR(10) NOT NULL CHECK (mercado IN ('BVQ','BVG'))
);

CREATE TABLE IF NOT EXISTS ordenes (
    id_orden          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_cuenta         UUID NOT NULL REFERENCES cuentas(id_cuenta) ON DELETE CASCADE,
    id_instrumento    UUID NOT NULL REFERENCES catalogo_instrumentos(id_instrumento),
    numero_orden      VARCHAR(20) NOT NULL UNIQUE,
    tipo_orden        VARCHAR(10) NOT NULL CHECK (tipo_orden IN ('compra','venta')),
    cantidad          INTEGER NOT NULL CHECK (cantidad > 0),
    precio_limite     NUMERIC(14,4),
    estado_orden      VARCHAR(15) NOT NULL DEFAULT 'pendiente'
                       CHECK (estado_orden IN ('pendiente','ejecutada','cancelada','rechazada')),
    fecha_creacion    TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_ejecucion   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS tickets (
    id_ticket         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_ticket     VARCHAR(20) UNIQUE,
    id_cliente        UUID NOT NULL REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    numero_cuenta     VARCHAR(20),
    numero_orden      VARCHAR(20),
    nombre_completo   VARCHAR(150),
    correo            VARCHAR(150),
    telefono          VARCHAR(20),
    motivo_consulta   VARCHAR(30) NOT NULL
                       CHECK (motivo_consulta IN ('orden_no_ejecutada','error_plataforma',
                                                   'reclamo_cobro','consulta_dividendo','otro')),
    descripcion       TEXT,
    estado_solicitud  VARCHAR(15) NOT NULL DEFAULT 'abierto'
                       CHECK (estado_solicitud IN ('abierto','en_proceso','resuelto','cerrado')),
    canal_origen      VARCHAR(20) NOT NULL DEFAULT 'chatbot',
    idempotency_key   VARCHAR(80) UNIQUE,
    fecha_registro    TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION fn_actualizar_fecha()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tickets_actualizar_fecha ON tickets;
CREATE TRIGGER trg_tickets_actualizar_fecha
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_fecha();

CREATE TABLE IF NOT EXISTS interacciones_chatbot (
    id_interaccion    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_cliente        UUID REFERENCES clientes(id_cliente),
    intent_detectado  VARCHAR(50) NOT NULL,
    mensaje_usuario   TEXT NOT NULL,
    respuesta_bot     TEXT NOT NULL,
    id_ticket         UUID REFERENCES tickets(id_ticket),
    fecha_interaccion TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Datos de prueba (mismos del prototipo) ----------

INSERT INTO clientes (cedula, nombre_completo, correo, telefono, perfil_riesgo) VALUES
  ('1712345678', 'María Fernanda López', 'mflopez@correo.com', '+593987654321', 'moderado'),
  ('0923456781', 'Carlos Ramírez', 'cramirez@correo.com', '+593998765432', 'conservador')
ON CONFLICT (cedula) DO NOTHING;

INSERT INTO cuentas (id_cliente, numero_cuenta, saldo_disponible, saldo_custodia)
SELECT id_cliente, 'AV-00234', 5230.50, 18420.00 FROM clientes WHERE cedula = '1712345678'
ON CONFLICT (numero_cuenta) DO NOTHING;

INSERT INTO cuentas (id_cliente, numero_cuenta, saldo_disponible, saldo_custodia)
SELECT id_cliente, 'AV-00591', 1120.00, 6200.00 FROM clientes WHERE cedula = '0923456781'
ON CONFLICT (numero_cuenta) DO NOTHING;

INSERT INTO catalogo_instrumentos (codigo_nemonico, nombre, tipo_instrumento, mercado) VALUES
  ('BPICHINCHA', 'BANCO PICHINCHA C.A.', 'accion', 'BVQ'),
  ('HOLCIMEC', 'HOLCIM ECUADOR', 'accion', 'BVG'),
  ('CERVNAC', 'CERVECERÍA NACIONAL', 'accion', 'BVG')
ON CONFLICT (codigo_nemonico) DO NOTHING;

INSERT INTO ordenes (id_cuenta, id_instrumento, numero_orden, tipo_orden, cantidad, estado_orden, fecha_ejecucion)
SELECT c.id_cuenta, i.id_instrumento, 'ORD-88213', 'compra', 150, 'ejecutada', now() - interval '2 hours'
FROM cuentas c, catalogo_instrumentos i WHERE c.numero_cuenta='AV-00234' AND i.codigo_nemonico='BPICHINCHA'
ON CONFLICT (numero_orden) DO NOTHING;

INSERT INTO ordenes (id_cuenta, id_instrumento, numero_orden, tipo_orden, cantidad, estado_orden)
SELECT c.id_cuenta, i.id_instrumento, 'ORD-88240', 'venta', 40, 'pendiente'
FROM cuentas c, catalogo_instrumentos i WHERE c.numero_cuenta='AV-00234' AND i.codigo_nemonico='HOLCIMEC'
ON CONFLICT (numero_orden) DO NOTHING;

INSERT INTO ordenes (id_cuenta, id_instrumento, numero_orden, tipo_orden, cantidad, estado_orden)
SELECT c.id_cuenta, i.id_instrumento, 'ORD-90110', 'compra', 25, 'cancelada'
FROM cuentas c, catalogo_instrumentos i WHERE c.numero_cuenta='AV-00591' AND i.codigo_nemonico='CERVNAC'
ON CONFLICT (numero_orden) DO NOTHING;

-- ---------- Seguridad a nivel de fila (RLS) ----------
-- Nota académica: estas políticas son permisivas a propósito para que el
-- prototipo funcione desde el navegador con la llave "anon" pública, tal
-- como se explica en el informe técnico (sección 7.1) para un entorno de
-- demostración. En producción se restringiría por sesión autenticada.

ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalogo_instrumentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE ordenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE interacciones_chatbot ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS demo_select_clientes ON clientes;
CREATE POLICY demo_select_clientes ON clientes FOR SELECT USING (true);

DROP POLICY IF EXISTS demo_select_cuentas ON cuentas;
CREATE POLICY demo_select_cuentas ON cuentas FOR SELECT USING (true);

DROP POLICY IF EXISTS demo_select_instrumentos ON catalogo_instrumentos;
CREATE POLICY demo_select_instrumentos ON catalogo_instrumentos FOR SELECT USING (true);

DROP POLICY IF EXISTS demo_select_ordenes ON ordenes;
CREATE POLICY demo_select_ordenes ON ordenes FOR SELECT USING (true);

DROP POLICY IF EXISTS demo_select_tickets ON tickets;
CREATE POLICY demo_select_tickets ON tickets FOR SELECT USING (true);
DROP POLICY IF EXISTS demo_insert_tickets ON tickets;
CREATE POLICY demo_insert_tickets ON tickets FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS demo_insert_interacciones ON interacciones_chatbot;
CREATE POLICY demo_insert_interacciones ON interacciones_chatbot FOR INSERT WITH CHECK (true);

-- ---------- Habilitar Realtime en tickets ----------
-- (En Supabase moderno también puedes activarlo desde Database > Replication > tickets)
ALTER PUBLICATION supabase_realtime ADD TABLE tickets;
