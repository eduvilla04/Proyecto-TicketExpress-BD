-- ==============================================================
-- TICKETEXPRESS+ | PROCEDIMIENTOS, FUNCIONES Y TRIGGERS
-- NOTA: se crea solamente auditoria_ventas, requerida por la tarea.
-- ==============================================================

-- REGLAS DE NEGOCIO DEL EJERCICIO
-- 1) Una venta incluye uno o varios asientos de una sola funcion.
-- 2) El asiento debe pertenecer al recinto de la funcion.
-- 3) Debe existir una tarifa habilitada para ese asiento y funcion.
-- 4) No se puede vender dos veces la misma tarifa (tique.idprecio UNIQUE).
-- 5) No se vende si la funcion ya paso o esta cancelada/finalizada.
-- 6) Cancelar una compra elimina sus tiques y libera sus tarifas.
--    Se usa DELETE porque tique.idprecio es UNIQUE y NOT NULL.
-- 7) El pago se conserva con estado 'cancelado' (historial).
-- 8) La auditoria conserva cada venta aun despues de cancelar.
-- 9) Fecha y hora de las funciones: hora local de El Salvador.
-- 10) Estados usados: funcion 'programada', tarifa 'disponible',
--     pago 'aprobado' y tique 'emitido'.

-- Ajustar secuencias si los datos se cargaron con ID explicitos (CSV/INSERT).
-- No cambia las tablas ni borra datos; evita colisiones al usar IDENTITY.
-- Nunca retrocede una secuencia si ya estaba mas adelantada.
DO $$
DECLARE
    v_secuencia REGCLASS;
    v_ultimo BIGINT;
    v_maximo BIGINT;
BEGIN
    v_secuencia := pg_get_serial_sequence('funcion', 'idfuncion')::REGCLASS;
    EXECUTE format('SELECT last_value FROM %s', v_secuencia) INTO v_ultimo;
    SELECT MAX(idfuncion) INTO v_maximo FROM funcion;
    IF v_maximo IS NOT NULL AND v_maximo >= v_ultimo THEN
        PERFORM setval(v_secuencia, v_maximo, TRUE);
    END IF;

    v_secuencia := pg_get_serial_sequence('pago', 'idpago')::REGCLASS;
    EXECUTE format('SELECT last_value FROM %s', v_secuencia) INTO v_ultimo;
    SELECT MAX(idpago) INTO v_maximo FROM pago;
    IF v_maximo IS NOT NULL AND v_maximo >= v_ultimo THEN
        PERFORM setval(v_secuencia, v_maximo, TRUE);
    END IF;

    v_secuencia := pg_get_serial_sequence('tique', 'idtique')::REGCLASS;
    EXECUTE format('SELECT last_value FROM %s', v_secuencia) INTO v_ultimo;
    SELECT MAX(idtique) INTO v_maximo FROM tique;
    IF v_maximo IS NOT NULL AND v_maximo >= v_ultimo THEN
        PERFORM setval(v_secuencia, v_maximo, TRUE);
    END IF;

    v_secuencia := pg_get_serial_sequence('tarifa', 'idtarifa')::REGCLASS;
    EXECUTE format('SELECT last_value FROM %s', v_secuencia) INTO v_ultimo;
    SELECT MAX(idtarifa) INTO v_maximo FROM tarifa;
    IF v_maximo IS NOT NULL AND v_maximo >= v_ultimo THEN
        PERFORM setval(v_secuencia, v_maximo, TRUE);
    END IF;
END;
$$;

-- ==============================================================
-- PARTE 1. PROCEDIMIENTOS ALMACENADOS
-- ==============================================================

-- A) Registrar la compra de uno o varios asientos en una funcion.
-- El procedimiento recibe ID de usuario, funcion y ARREGLO de ID de asiento.

CREATE OR REPLACE PROCEDURE registrar_compra_tiques(
    IN p_idusuario BIGINT,
    IN p_idfuncion BIGINT,
    IN p_asientos BIGINT[],
    IN p_metodo_pago VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_recinto BIGINT;
    v_fecha DATE;
    v_hora TIME;
    v_estado_funcion VARCHAR(30);
    v_estado_usuario VARCHAR(30);
    v_asiento BIGINT;
    v_idtarifa BIGINT;
    v_precio NUMERIC(10,2);
    v_estado_tarifa VARCHAR(30);
    v_total NUMERIC(10,2) := 0;
    v_idpago BIGINT;
    v_idtique BIGINT;
    v_cantidad INTEGER;
    v_distintos INTEGER;
BEGIN
    IF p_idusuario IS NULL OR p_idfuncion IS NULL THEN
        RAISE EXCEPTION 'Debes indicar un usuario y una funcion';
    END IF;

    IF p_asientos IS NULL OR cardinality(p_asientos) = 0 THEN
        RAISE EXCEPTION 'Debes seleccionar al menos un asiento';
    END IF;

    IF p_metodo_pago IS NULL OR BTRIM(p_metodo_pago) = '' THEN
        RAISE EXCEPTION 'Debes indicar el metodo de pago';
    END IF;

    IF array_position(p_asientos, NULL) IS NOT NULL THEN
        RAISE EXCEPTION 'La lista contiene un asiento nulo';
    END IF;

    SELECT COUNT(*), COUNT(DISTINCT x)
      INTO v_cantidad, v_distintos
      FROM unnest(p_asientos) AS datos(x);

    IF v_cantidad <> v_distintos THEN
        RAISE EXCEPTION 'La lista de asientos contiene ID repetidos';
    END IF;

    SELECT u.estado
      INTO v_estado_usuario
      FROM usuario u
     WHERE u.idusuario = p_idusuario;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El usuario % no existe', p_idusuario;
    END IF;

    IF LOWER(BTRIM(v_estado_usuario)) <> 'activo' THEN
        RAISE EXCEPTION 'El usuario % no puede comprar: estado %',
            p_idusuario, v_estado_usuario;
    END IF;

    -- Bloqueo de la funcion para evitar compras simultaneas incompatibles.
    SELECT f.idrecinto, f.fecha, f.hora, f.estado
      INTO v_recinto, v_fecha, v_hora, v_estado_funcion
      FROM funcion f
     WHERE f.idfuncion = p_idfuncion
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La funcion % no existe', p_idfuncion;
    END IF;

    IF v_fecha + v_hora <= (clock_timestamp() AT TIME ZONE 'America/El_Salvador') THEN
        RAISE EXCEPTION 'No se puede comprar: la funcion % ya paso', p_idfuncion;
    END IF;

    IF LOWER(BTRIM(v_estado_funcion)) IN
       ('cancelada', 'cancelado', 'finalizada', 'finalizado', 'suspendida', 'suspendido') THEN
        RAISE EXCEPTION 'La funcion % no esta habilitada: %',
            p_idfuncion, v_estado_funcion;
    END IF;

    -- Verificar todos los asientos antes de registrar el pago.
    FOREACH v_asiento IN ARRAY p_asientos LOOP
        SELECT ta.idtarifa, ta.precio, ta.estado
          INTO v_idtarifa, v_precio, v_estado_tarifa
          FROM tarifa ta
          JOIN asiento a ON a.idasiento = ta.idasiento
         WHERE ta.idfuncion = p_idfuncion
           AND ta.idasiento = v_asiento
           AND a.idrecinto = v_recinto
         FOR UPDATE OF ta;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Asiento %: no tiene tarifa para la funcion % o no pertenece al recinto',
                v_asiento, p_idfuncion;
        END IF;

        IF LOWER(BTRIM(v_estado_tarifa)) NOT IN
           ('disponible', 'libre') THEN
            RAISE EXCEPTION 'Asiento % no disponible: tarifa en estado %',
                v_asiento, v_estado_tarifa;
        END IF;

        PERFORM 1 FROM tique WHERE idprecio = v_idtarifa;
        IF FOUND THEN
            RAISE EXCEPTION 'El asiento % ya tiene un tique vendido', v_asiento;
        END IF;

        v_total := v_total + v_precio;
    END LOOP;

    -- Un pago puede agrupar varios tiques de la misma funcion.
    INSERT INTO pago (fecha, hora, montototal, metodopago, estado, idusuario)
    VALUES (
        (clock_timestamp() AT TIME ZONE 'America/El_Salvador')::DATE,
        (clock_timestamp() AT TIME ZONE 'America/El_Salvador')::TIME,
        v_total, BTRIM(p_metodo_pago), 'aprobado', p_idusuario
    )
    RETURNING idpago INTO v_idpago;

    FOREACH v_asiento IN ARRAY p_asientos LOOP
        SELECT ta.idtarifa, ta.precio
          INTO v_idtarifa, v_precio
          FROM tarifa ta
         WHERE ta.idfuncion = p_idfuncion
           AND ta.idasiento = v_asiento;

        INSERT INTO tique (codigo, preciopagado, estado, idprecio, idpago, idusuario)
        VALUES (
            'TE-' || UPPER(SUBSTRING(
                MD5(clock_timestamp()::TEXT || random()::TEXT || v_idtarifa::TEXT)
                FROM 1 FOR 24
            )),
            v_precio, 'emitido', v_idtarifa, v_idpago, p_idusuario
        )
        RETURNING idtique INTO v_idtique;

        UPDATE tarifa
           SET estado = 'vendida'
         WHERE idtarifa = v_idtarifa;
    END LOOP;

    RAISE NOTICE 'Compra registrada. Pago: %, tiques: %, total: $%',
        v_idpago, v_cantidad, v_total;
END;
$$;


-- B) Cancelar una compra completa usando el ID del pago.
-- Se pide tambien el usuario para verificar que es el comprador.
-- El procedimiento recibe ID de pago y usuario comprador.

CREATE OR REPLACE PROCEDURE cancelar_compra_tiques(
    IN p_idpago BIGINT,
    IN p_idusuario BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_idusuario_pago BIGINT;
    v_estado_pago VARCHAR(30);
    v_cantidad INTEGER := 0;
    v_tique RECORD;
BEGIN
    SELECT p.idusuario, p.estado
      INTO v_idusuario_pago, v_estado_pago
      FROM pago p
     WHERE p.idpago = p_idpago
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago % no existe', p_idpago;
    END IF;

    IF p_idusuario IS NULL OR v_idusuario_pago <> p_idusuario THEN
        RAISE EXCEPTION 'El pago % no pertenece al usuario %', p_idpago, p_idusuario;
    END IF;

    IF LOWER(BTRIM(v_estado_pago)) = 'cancelado' THEN
        RAISE EXCEPTION 'La compra % ya fue cancelada', p_idpago;
    END IF;

    -- Conservar el pago, pero eliminar los tiques para poder revender.
    -- La auditoria de las ventas originales no se elimina.
    FOR v_tique IN
        SELECT t.idtique, t.idprecio
          FROM tique t
         WHERE t.idpago = p_idpago
         ORDER BY t.idtique
         FOR UPDATE
    LOOP
        DELETE FROM tique
         WHERE idtique = v_tique.idtique;

        UPDATE tarifa
           SET estado = 'disponible'
         WHERE idtarifa = v_tique.idprecio;

        v_cantidad := v_cantidad + 1;
    END LOOP;

    IF v_cantidad = 0 THEN
        RAISE EXCEPTION 'El pago % no contiene tiques para cancelar', p_idpago;
    END IF;

    UPDATE pago
       SET estado = 'cancelado'
     WHERE idpago = p_idpago;

    RAISE NOTICE 'Compra % cancelada. Tiques liberados: %',
        p_idpago, v_cantidad;
END;
$$;



-- ==============================================================
-- PARTE 2. FUNCIONES
-- ==============================================================

-- A) Cuantos asientos pueden comprarse en una funcion.
-- Se cuentan solo los asientos CON tarifa habilitada y sin tique.

CREATE OR REPLACE FUNCTION consultar_asientos_disponibles(p_idfuncion BIGINT)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total INTEGER;
    v_fecha DATE;
    v_hora TIME;
    v_estado VARCHAR(30);
BEGIN
    SELECT fecha, hora, estado
      INTO v_fecha, v_hora, v_estado
      FROM funcion
     WHERE idfuncion = p_idfuncion;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La funcion % no existe', p_idfuncion;
    END IF;

    IF v_fecha + v_hora <= (clock_timestamp() AT TIME ZONE 'America/El_Salvador')
       OR LOWER(BTRIM(v_estado)) IN
          ('cancelada', 'cancelado', 'finalizada', 'finalizado', 'suspendida', 'suspendido') THEN
        RETURN 0;
    END IF;

    SELECT COUNT(*)::INTEGER
      INTO v_total
      FROM tarifa ta
      JOIN asiento a ON a.idasiento = ta.idasiento
      JOIN funcion f ON f.idfuncion = ta.idfuncion
     WHERE ta.idfuncion = p_idfuncion
       AND a.idrecinto = f.idrecinto
       AND LOWER(BTRIM(ta.estado)) IN
           ('disponible', 'libre')
       AND NOT EXISTS (
           SELECT 1 FROM tique t WHERE t.idprecio = ta.idtarifa
       );

    RETURN v_total;
END;
$$;


-- B) Ingresos acumulados por evento (no por funcion).
-- Se consideran tiques emitidos y pagos aprobados.

CREATE OR REPLACE FUNCTION calcular_ingresos_evento(p_idevento BIGINT)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(t.preciopagado), 0)::NUMERIC(12,2)
      INTO v_total
      FROM evento e
      JOIN funcion f ON f.idevento = e.idevento
      JOIN tarifa ta ON ta.idfuncion = f.idfuncion
      JOIN tique t ON t.idprecio = ta.idtarifa
      JOIN pago p ON p.idpago = t.idpago
     WHERE e.idevento = p_idevento
       AND LOWER(BTRIM(t.estado)) IN ('emitido', 'vendido', 'activo')
       AND LOWER(BTRIM(p.estado)) IN ('aprobado', 'pagado', 'completado');

    RETURN v_total;
END;
$$;


-- ==============================================================
-- PARTE 3. DISPARADORES (TRIGGERS)
-- ==============================================================

-- A) Tabla de auditoria: no tiene FK hacia tique, para que los
-- registros historicos no desaparezcan al cancelar una compra.
CREATE TABLE IF NOT EXISTS auditoria_ventas (
    idauditoria BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    idtique BIGINT NOT NULL,
    fecha_venta TIMESTAMP NOT NULL,
    idusuario BIGINT NOT NULL,
    usuario_bd TEXT NOT NULL,
    idpago BIGINT NOT NULL,
    idfuncion BIGINT NOT NULL
);

CREATE OR REPLACE FUNCTION registrar_auditoria_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_idfuncion BIGINT;
BEGIN
    SELECT ta.idfuncion
      INTO v_idfuncion
      FROM tarifa ta
     WHERE ta.idtarifa = NEW.idprecio;

    INSERT INTO auditoria_ventas
        (idtique, fecha_venta, idusuario, usuario_bd, idpago, idfuncion)
    VALUES
        (NEW.idtique, NEW.fechaemision, NEW.idusuario,
         CURRENT_USER, NEW.idpago, v_idfuncion);

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditoria_ventas ON tique;

CREATE TRIGGER trg_auditoria_ventas
AFTER INSERT ON tique
FOR EACH ROW
EXECUTE FUNCTION registrar_auditoria_venta();


-- B) Impedir nuevas ventas de funciones que ya pasaron.
-- La validacion se hace tambien si alguien inserta un tique
-- directamente, sin usar el procedimiento de compra.

CREATE OR REPLACE FUNCTION validar_horario_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha DATE;
    v_hora TIME;
    v_estado VARCHAR(30);
BEGIN
    SELECT f.fecha, f.hora, f.estado
      INTO v_fecha, v_hora, v_estado
      FROM tarifa ta
      JOIN funcion f ON f.idfuncion = ta.idfuncion
     WHERE ta.idtarifa = NEW.idprecio;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La tarifa % no corresponde a una funcion existente',
            NEW.idprecio;
    END IF;

    IF v_fecha + v_hora <= (clock_timestamp() AT TIME ZONE 'America/El_Salvador') THEN
        RAISE EXCEPTION 'VENTA FUERA DE TIEMPO: la funcion ya finalizo';
    END IF;

    IF LOWER(BTRIM(v_estado)) IN
       ('cancelada', 'cancelado', 'finalizada', 'finalizado', 'suspendida', 'suspendido') THEN
        RAISE EXCEPTION 'Venta rechazada: funcion con estado %', v_estado;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_horario_venta ON tique;

CREATE TRIGGER trg_validar_horario_venta
BEFORE INSERT ON tique
FOR EACH ROW
EXECUTE FUNCTION validar_horario_venta();


-- ==============================================================
-- COMPROBACIONES (SOLO SELECT, NO REGISTRAN COMPRAS)
-- ==============================================================

-- Ver los procedimientos y funciones creados.
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = current_schema()
  AND routine_name IN (
      'registrar_compra_tiques',
      'cancelar_compra_tiques',
      'consultar_asientos_disponibles',
      'calcular_ingresos_evento'
  )
ORDER BY routine_name;

-- Ver los dos triggers vinculados a tique.
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'tique'
  AND trigger_name IN ('trg_auditoria_ventas', 'trg_validar_horario_venta')
ORDER BY trigger_name;

-- Ver las ventas auditadas (inicialmente puede estar vacia).
SELECT * FROM auditoria_ventas ORDER BY idauditoria DESC;
