-- TicketExpress+ - Pruebas de seguridad (entrega final)
--Crear las 3 diferentes conexionas para poder hacer las pruebas

-- A. CONEXION admin_ticket
SELECT session_user, current_user, current_database();

SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname = 'admin_ticket';

-- Prueba de permisos y auditoria (conserva tres registros de auditoria).
DO $$
DECLARE
    v_usuario BIGINT;
    v_pago BIGINT;
    v_registros INTEGER;
BEGIN
    IF session_user <> 'admin_ticket' OR current_user <> 'admin_ticket'
       OR current_database() <> 'ticketexpress' THEN
        RAISE EXCEPTION 'Conectate a ticketexpress como admin_ticket';
    END IF;

    PERFORM 1 FROM public.evento LIMIT 1;
    PERFORM 1 FROM public.pago LIMIT 1;
    UPDATE public.evento SET nombre = nombre WHERE FALSE;

    SELECT idusuario INTO v_usuario
    FROM public.usuario ORDER BY idusuario LIMIT 1;
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'Se requiere al menos un usuario registrado';
    END IF;

    INSERT INTO public.pago (fecha, hora, montototal, metodopago, estado, idusuario)
    VALUES (CURRENT_DATE, LOCALTIME, 10.00, 'tarjeta', 'aprobado', v_usuario)
    RETURNING idpago INTO v_pago;

    UPDATE public.pago SET estado = 'cancelado' WHERE idpago = v_pago;
    DELETE FROM public.pago WHERE idpago = v_pago;

    SELECT COUNT(*) INTO v_registros FROM public.auditoria_pago
    WHERE idpago = v_pago AND usuario_bd = session_user;

    IF v_registros <> 3 OR NOT EXISTS (
        SELECT 1 FROM public.auditoria_pago
        WHERE idpago = v_pago AND usuario_bd = session_user
          AND operacion = 'INSERT' AND datos_anteriores IS NULL
          AND datos_nuevos->>'estado' = 'aprobado'
    ) OR NOT EXISTS (
        SELECT 1 FROM public.auditoria_pago
        WHERE idpago = v_pago AND usuario_bd = session_user
          AND operacion = 'UPDATE' AND datos_anteriores->>'estado' = 'aprobado'
          AND datos_nuevos->>'estado' = 'cancelado'
    ) OR NOT EXISTS (
        SELECT 1 FROM public.auditoria_pago
        WHERE idpago = v_pago AND usuario_bd = session_user
          AND operacion = 'DELETE' AND datos_anteriores->>'estado' = 'cancelado'
          AND datos_nuevos IS NULL
    ) OR EXISTS (SELECT 1 FROM public.pago WHERE idpago = v_pago) THEN
        RAISE EXCEPTION 'Fallo la prueba de auditoria del pago %', v_pago;
    END IF;

    RAISE NOTICE 'OK administrador: INSERT, UPDATE y DELETE auditados. Pago %', v_pago;
END;
$$;

-- Evidencia: ultimas tres operaciones del administrador.
SELECT idauditoria, idpago, operacion, fecha, usuario_bd,
       datos_anteriores, datos_nuevos
FROM public.auditoria_pago
WHERE usuario_bd = 'admin_ticket'
ORDER BY idauditoria DESC LIMIT 3;

-- El administrador no debe poder modificar la auditoria.
-- La excepcion esperada se captura para no interrumpir las pruebas.
DO $$
BEGIN
    IF session_user <> 'admin_ticket' OR current_user <> 'admin_ticket'
       OR current_database() <> 'ticketexpress' THEN
        RAISE EXCEPTION 'Conectate como admin_ticket';
    END IF;
    BEGIN
        DELETE FROM public.auditoria_pago WHERE FALSE;
        RAISE EXCEPTION 'FALLO: administrador puede borrar auditoria';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: administrador no puede borrar auditoria';
    END;
END;
$$;

-- B. CONEXION operador_ticket
SELECT session_user, current_user, current_database();

-- Consultas autorizadas y permisos de ejecucion.
DO $$
BEGIN
    IF session_user <> 'operador_ticket' OR current_user <> 'operador_ticket'
       OR current_database() <> 'ticketexpress' THEN
        RAISE EXCEPTION 'Conectate a ticketexpress como operador_ticket';
    END IF;
    PERFORM 1 FROM public.evento LIMIT 1;
    PERFORM idusuario, nombre, apellido, estado FROM public.usuario LIMIT 1;
    PERFORM 1 FROM public.pago LIMIT 1;
    PERFORM 1 FROM public.tique LIMIT 1;
    IF NOT has_function_privilege(current_user,
        'public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)', 'EXECUTE')
       OR NOT has_function_privilege(current_user,
        'public.cancelar_compra_tiques(bigint,bigint)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FALLO: operador sin permiso para compra o cancelacion';
    END IF;
    RAISE NOTICE 'OK: operador puede consultar y ejecutar los procedimientos';

    BEGIN
        PERFORM clave FROM public.usuario LIMIT 1;
        RAISE EXCEPTION 'FALLO: operador puede leer claves';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: operador no puede leer claves';
    END;
    BEGIN
        UPDATE public.pago SET estado = 'cancelado' WHERE FALSE;
        RAISE EXCEPTION 'FALLO: operador puede actualizar pagos directamente';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: operador no puede actualizar pagos directamente';
    END;
    BEGIN
        DELETE FROM public.tique WHERE FALSE;
        RAISE EXCEPTION 'FALLO: operador puede borrar tiques directamente';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: operador no puede borrar tiques directamente';
    END;
    BEGIN
        PERFORM 1 FROM public.auditoria_pago LIMIT 1;
        RAISE EXCEPTION 'FALLO: operador puede consultar auditoria';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: operador no puede consultar auditoria';
    END;
END;
$$;

-- Evidencia visible de los permisos del operador.
SELECT idusuario, nombre, apellido, estado FROM public.usuario LIMIT 5;
SELECT has_function_privilege(current_user,
    'public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)', 'EXECUTE') AS puede_comprar,
    has_function_privilege(current_user,
    'public.cancelar_compra_tiques(bigint,bigint)', 'EXECUTE') AS puede_cancelar;

-- Prueba real de compra y cancelacion.
-- Usa una funcion futura con tarifa libre existente.
-- Revierte la compra, la cancelacion y la auditoria de esta prueba.
-- Los contadores de las secuencias pueden avanzar (normal en PostgreSQL).
DO $$
DECLARE
    v_usuario BIGINT;
    v_funcion BIGINT;
    v_asiento BIGINT;
    v_tarifa BIGINT;
    v_pago BIGINT;
    v_antes INTEGER;
    v_despues INTEGER;
BEGIN
    IF session_user <> 'operador_ticket' OR current_user <> 'operador_ticket'
       OR current_database() <> 'ticketexpress' THEN
        RAISE EXCEPTION 'Conectate como operador_ticket';
    END IF;

    SELECT idusuario INTO v_usuario FROM public.usuario
    WHERE lower(btrim(estado)) = 'activo' ORDER BY idusuario LIMIT 1;

    SELECT f.idfuncion, ta.idasiento, ta.idtarifa
    INTO v_funcion, v_asiento, v_tarifa
    FROM public.funcion f
    JOIN public.tarifa ta ON ta.idfuncion = f.idfuncion
    JOIN public.asiento a ON a.idasiento = ta.idasiento AND a.idrecinto = f.idrecinto
    WHERE f.fecha + f.hora > (clock_timestamp() AT TIME ZONE 'America/El_Salvador')
      AND lower(btrim(f.estado)) NOT IN
          ('cancelada','cancelado','finalizada','finalizado','suspendida','suspendido')
      AND lower(btrim(ta.estado)) IN ('disponible','libre')
      AND NOT EXISTS (SELECT 1 FROM public.tique t WHERE t.idprecio = ta.idtarifa)
    ORDER BY f.idfuncion, ta.idasiento LIMIT 1;

    IF v_usuario IS NULL OR v_funcion IS NULL THEN
        RAISE EXCEPTION 'Se requiere usuario activo y funcion futura con tarifa libre';
    END IF;

    BEGIN
        v_antes := public.consultar_asientos_disponibles(v_funcion);
        CALL public.registrar_compra_tiques(v_usuario, v_funcion, ARRAY[v_asiento], 'tarjeta');

        SELECT t.idpago INTO STRICT v_pago
        FROM public.tique t
        WHERE t.idprecio = v_tarifa AND t.idusuario = v_usuario;
        v_despues := public.consultar_asientos_disponibles(v_funcion);
        IF v_despues <> v_antes - 1 OR NOT EXISTS (
            SELECT 1 FROM public.pago WHERE idpago = v_pago AND estado = 'aprobado'
        ) OR NOT EXISTS (
            SELECT 1 FROM public.tarifa WHERE idtarifa = v_tarifa AND estado = 'vendida'
        ) THEN
            RAISE EXCEPTION 'FALLO: la compra no actualizo pago o disponibilidad';
        END IF;
        RAISE NOTICE 'OK compra: pago %, disponibilidad % -> %', v_pago, v_antes, v_despues;

        CALL public.cancelar_compra_tiques(v_pago, v_usuario);
        v_despues := public.consultar_asientos_disponibles(v_funcion);
        IF v_despues <> v_antes OR EXISTS (
            SELECT 1 FROM public.tique WHERE idpago = v_pago
        ) OR NOT EXISTS (
            SELECT 1 FROM public.pago WHERE idpago = v_pago AND estado = 'cancelado'
        ) OR NOT EXISTS (
            SELECT 1 FROM public.tarifa WHERE idtarifa = v_tarifa AND estado = 'disponible'
        ) THEN
            RAISE EXCEPTION 'FALLO: la cancelacion no libero el asiento';
        END IF;
        RAISE NOTICE 'OK cancelacion: pago %, disponibilidad %', v_pago, v_despues;

        -- Excepcion controlada: deshacer solo las operaciones de la prueba.
        RAISE EXCEPTION USING ERRCODE = 'ZX001', MESSAGE = 'Revertir prueba de operador';
    EXCEPTION WHEN SQLSTATE 'ZX001' THEN
        RAISE NOTICE 'OK: compra y cancelacion verificadas; cambios de prueba revertidos';
    END;

    IF EXISTS (SELECT 1 FROM public.pago WHERE idpago = v_pago) THEN
        RAISE EXCEPTION 'FALLO: el pago de prueba no se revirtio';
    END IF;
END;
$$;

-- C. CONEXION analista_ticket
SELECT session_user, current_user, current_database();

DO $$
BEGIN
    IF session_user <> 'analista_ticket' OR current_user <> 'analista_ticket'
       OR current_database() <> 'ticketexpress' THEN
        RAISE EXCEPTION 'Conectate a ticketexpress como analista_ticket';
    END IF;
    PERFORM 1 FROM public.evento LIMIT 1;
    PERFORM public.calcular_ingresos_evento(idevento) FROM public.evento LIMIT 1;
    PERFORM public.consultar_asientos_disponibles(idfuncion) FROM public.funcion LIMIT 1;
    IF has_function_privilege(current_user,
        'public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)', 'EXECUTE')
       OR has_function_privilege(current_user,
        'public.cancelar_compra_tiques(bigint,bigint)', 'EXECUTE') THEN
        RAISE EXCEPTION 'FALLO: analista puede ejecutar procedimientos de venta';
    END IF;
    RAISE NOTICE 'OK: analista puede consultar las funciones, no los procedimientos de venta';

    BEGIN
        PERFORM 1 FROM public.usuario LIMIT 1;
        RAISE EXCEPTION 'FALLO: analista puede consultar usuarios';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: analista no puede consultar usuarios';
    END;
    BEGIN
        PERFORM 1 FROM public.pago LIMIT 1;
        RAISE EXCEPTION 'FALLO: analista puede consultar pagos';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: analista no puede consultar pagos';
    END;
    BEGIN
        DELETE FROM public.tique WHERE FALSE;
        RAISE EXCEPTION 'FALLO: analista puede borrar tiques';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: analista no puede borrar tiques';
    END;
    BEGIN
        PERFORM 1 FROM public.auditoria_pago LIMIT 1;
        RAISE EXCEPTION 'FALLO: analista puede consultar auditoria';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE 'OK: analista no puede consultar auditoria';
    END;
END;
$$;

-- Evidencia visible de las consultas autorizadas.
SELECT idevento, nombre, public.calcular_ingresos_evento(idevento) AS ingresos
FROM public.evento ORDER BY idevento LIMIT 5;
SELECT idfuncion, public.consultar_asientos_disponibles(idfuncion) AS libres
FROM public.funcion ORDER BY idfuncion LIMIT 5;
SELECT has_function_privilege(current_user,
    'public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)', 'EXECUTE') AS puede_comprar,
    has_function_privilege(current_user,
    'public.cancelar_compra_tiques(bigint,bigint)', 'EXECUTE') AS puede_cancelar;

-- D. CONEXION postgres (o admin_ticket). Revision final de auditoria.
-- No ejecutar como analista u operador: tienen acceso denegado.
SELECT idauditoria, idpago, operacion, fecha, usuario_bd
FROM public.auditoria_pago ORDER BY idauditoria DESC;

-- Evidencia adicional opcional: ejecutar individualmente, con los logins indicados.
-- Se espera ERROR 42501 (permiso denegado), no un fallo de la instalacion.
-- operador_ticket: SELECT clave FROM public.usuario;
-- operador_ticket: UPDATE public.pago SET estado = 'cancelado' WHERE FALSE;
-- analista_ticket: SELECT * FROM public.pago;
-- analista_ticket: DELETE FROM public.tique WHERE FALSE;
