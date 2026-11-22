
-- ============================================================
-- TICKETEXPRESS+ - PRUEBAS DE PROCEDIMIENTOS, FUNCIONES Y TRIGGERS
-- Base de datos: ticketexpress
-- Ejecutar despues de crear los procedimientos y triggers.
-- ============================================================


-- ============================================================
-- PASO 1. Crear una tabla temporal para guardar los IDs
-- ============================================================

CREATE TEMP TABLE IF NOT EXISTS te_demo_ids (
    idusuario BIGINT,
    idfuncion BIGINT,
    idpago BIGINT,
    idasiento1 BIGINT,
    idasiento2 BIGINT
) ON COMMIT PRESERVE ROWS;

TRUNCATE TABLE pg_temp.te_demo_ids;


-- ============================================================
-- PASO 2. Preparar una funcion futura con dos asientos
-- ============================================================

DO $demo$
DECLARE
    v_idusuario BIGINT;
    v_idevento BIGINT;
    v_idrecinto BIGINT;
    v_asientos BIGINT[];
    v_idfuncion BIGINT;
BEGIN

    SELECT idusuario
    INTO v_idusuario
    FROM usuario
    WHERE LOWER(BTRIM(estado)) = 'activo'
    ORDER BY idusuario
    LIMIT 1;

    SELECT idevento
    INTO v_idevento
    FROM evento
    ORDER BY idevento
    LIMIT 1;

    SELECT idrecinto
    INTO v_idrecinto
    FROM asiento
    GROUP BY idrecinto
    HAVING COUNT(*) >= 2
    ORDER BY idrecinto
    LIMIT 1;

    IF v_idusuario IS NULL
       OR v_idevento IS NULL
       OR v_idrecinto IS NULL THEN

        RAISE EXCEPTION
        'Faltan usuarios, eventos o recintos con dos asientos';

    END IF;

    SELECT ARRAY(
        SELECT idasiento
        FROM asiento
        WHERE idrecinto = v_idrecinto
        ORDER BY idasiento
        LIMIT 2
    )
    INTO v_asientos;

    INSERT INTO funcion (
        fecha,
        hora,
        idevento,
        idrecinto,
        estado
    )
    VALUES (
        (clock_timestamp() AT TIME ZONE 'America/El_Salvador')::DATE + 14,
        '19:00',
        v_idevento,
        v_idrecinto,
        'programada'
    )
    RETURNING idfuncion INTO v_idfuncion;

    INSERT INTO tarifa (
        precio,
        estado,
        idfuncion,
        idasiento
    )
    SELECT
        30.00,
        'disponible',
        v_idfuncion,
        s.idasiento
    FROM unnest(v_asientos) AS s(idasiento);

    INSERT INTO pg_temp.te_demo_ids (
        idusuario,
        idfuncion,
        idasiento1,
        idasiento2
    )
    VALUES (
        v_idusuario,
        v_idfuncion,
        v_asientos[1],
        v_asientos[2]
    );

    RAISE NOTICE
    'Funcion creada: %, usuario: %, asientos: %',
    v_idfuncion, v_idusuario, v_asientos;

END;
$demo$;


-- ============================================================
-- PASO 3. Registrar la compra de dos tiques
-- CORREGIDO: ahora CALL utiliza variables
-- ============================================================

DO $demo$
DECLARE
    v_idusuario BIGINT;
    v_idfuncion BIGINT;
    v_asientos BIGINT[];
    v_idpago BIGINT;
BEGIN

    SELECT
        idusuario,
        idfuncion,
        ARRAY[idasiento1, idasiento2]
    INTO
        v_idusuario,
        v_idfuncion,
        v_asientos
    FROM pg_temp.te_demo_ids
    LIMIT 1;

    IF v_idusuario IS NULL OR v_idfuncion IS NULL THEN
        RAISE EXCEPTION
        'Primero debes preparar los datos de la prueba';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM tique t
        JOIN tarifa ta ON ta.idtarifa = t.idprecio
        WHERE ta.idfuncion = v_idfuncion
    ) THEN
        RAISE EXCEPTION
        'La funcion ya tiene tiques. No repitas la compra';
    END IF;

    CALL registrar_compra_tiques(
        v_idusuario,
        v_idfuncion,
        v_asientos,
        'tarjeta'
    );

    SELECT t.idpago
    INTO v_idpago
    FROM tique t
    JOIN tarifa ta ON ta.idtarifa = t.idprecio
    WHERE ta.idfuncion = v_idfuncion
      AND t.idusuario = v_idusuario
    ORDER BY t.idtique DESC
    LIMIT 1;

    IF v_idpago IS NULL THEN
        RAISE EXCEPTION
        'No se encontro el pago de la compra';
    END IF;

    UPDATE pg_temp.te_demo_ids
    SET idpago = v_idpago
    WHERE idfuncion = v_idfuncion;

    RAISE NOTICE
    'Compra realizada. ID del pago: %',
    v_idpago;

END;
$demo$;


-- ============================================================
-- PASO 4. Verificar compra y auditoria
-- ============================================================

-- Mostrar los tiques comprados

SELECT
    d.idpago,
    d.idusuario,
    d.idfuncion,
    t.idtique,
    t.codigo,
    t.preciopagado,
    t.estado AS estado_tique,
    ta.idasiento,
    ta.estado AS estado_tarifa
FROM pg_temp.te_demo_ids d
JOIN tique t
    ON t.idpago = d.idpago
JOIN tarifa ta
    ON ta.idtarifa = t.idprecio
ORDER BY t.idtique;


-- Mostrar los registros de auditoria

SELECT
    a.idauditoria,
    a.idtique,
    a.fecha_venta,
    a.idusuario,
    a.usuario_bd,
    a.idpago,
    a.idfuncion
FROM auditoria_ventas a
JOIN pg_temp.te_demo_ids d
    ON d.idpago = a.idpago
ORDER BY a.idauditoria;


-- ============================================================
-- PASO 5. Ejecutar las dos funciones
-- ============================================================

-- Consultar asientos disponibles

SELECT
    d.idfuncion,
    consultar_asientos_disponibles(d.idfuncion)
        AS asientos_disponibles
FROM pg_temp.te_demo_ids d;


-- Calcular los ingresos acumulados por evento

SELECT
    e.idevento,
    e.nombre,
    calcular_ingresos_evento(e.idevento)
        AS ingresos_acumulados
FROM pg_temp.te_demo_ids d
JOIN funcion f
    ON f.idfuncion = d.idfuncion
JOIN evento e
    ON e.idevento = f.idevento;


-- ============================================================
-- PASO 6. Cancelar la compra
-- CORREGIDO: CALL recibe variables, no subconsultas
-- ============================================================

DO $demo$
DECLARE
    v_idpago BIGINT;
    v_idusuario BIGINT;
    v_idfuncion BIGINT;
BEGIN

    SELECT
        idpago,
        idusuario,
        idfuncion
    INTO
        v_idpago,
        v_idusuario,
        v_idfuncion
    FROM pg_temp.te_demo_ids
    LIMIT 1;

    IF v_idusuario IS NULL OR v_idfuncion IS NULL THEN
        RAISE EXCEPTION
        'No se encontraron datos de la compra';
    END IF;

    -- Recuperar el pago si no quedo guardado en la tabla temporal

    IF v_idpago IS NULL THEN

        SELECT t.idpago
        INTO v_idpago
        FROM tique t
        JOIN tarifa ta
            ON ta.idtarifa = t.idprecio
        WHERE ta.idfuncion = v_idfuncion
          AND t.idusuario = v_idusuario
        ORDER BY t.idtique DESC
        LIMIT 1;

        UPDATE pg_temp.te_demo_ids
        SET idpago = v_idpago
        WHERE idfuncion = v_idfuncion;

    END IF;

    IF v_idpago IS NULL THEN
        RAISE EXCEPTION
        'No existe un pago para cancelar';
    END IF;

    CALL cancelar_compra_tiques(
        v_idpago,
        v_idusuario
    );

    RAISE NOTICE
    'Compra cancelada correctamente. Pago: %',
    v_idpago;

END;
$demo$;


-- ============================================================
-- PASO 7. Verificar la cancelacion
-- ============================================================

-- Consultar el estado del pago

SELECT
    p.idpago,
    p.estado AS estado_pago,
    COUNT(t.idtique) AS tiques_restantes
FROM pago p
JOIN pg_temp.te_demo_ids d
    ON d.idpago = p.idpago
LEFT JOIN tique t
    ON t.idpago = p.idpago
GROUP BY
    p.idpago,
    p.estado;


-- Consultar si los asientos volvieron a estar disponibles

SELECT
    d.idfuncion,
    consultar_asientos_disponibles(d.idfuncion)
        AS asientos_liberados
FROM pg_temp.te_demo_ids d;


-- Comprobar que se conserva la auditoria

SELECT
    a.idauditoria,
    a.idtique,
    a.fecha_venta,
    a.idusuario,
    a.idpago
FROM auditoria_ventas a
JOIN pg_temp.te_demo_ids d
    ON d.idpago = a.idpago
ORDER BY a.idauditoria;


-- ============================================================
-- PASO 8. Comprobar el trigger de venta fuera de tiempo
-- ============================================================

DO $demo$
DECLARE
    v_idusuario BIGINT;
    v_idevento BIGINT;
    v_idrecinto BIGINT;
    v_idasiento BIGINT;
    v_idfuncion BIGINT;
    v_idtarifa BIGINT;
    v_idpago BIGINT;
BEGIN

    SELECT idusuario
    INTO v_idusuario
    FROM usuario
    WHERE LOWER(BTRIM(estado)) = 'activo'
    ORDER BY idusuario
    LIMIT 1;

    SELECT idevento
    INTO v_idevento
    FROM evento
    ORDER BY idevento
    LIMIT 1;

    SELECT idasiento, idrecinto
    INTO v_idasiento, v_idrecinto
    FROM asiento
    ORDER BY idasiento
    LIMIT 1;

    IF v_idusuario IS NULL
       OR v_idevento IS NULL
       OR v_idasiento IS NULL THEN

        RAISE EXCEPTION
        'Faltan datos para probar el trigger';

    END IF;

    -- Las inserciones de esta prueba se revierten
    -- cuando el trigger rechaza la venta

    BEGIN

        INSERT INTO funcion (
            fecha,
            hora,
            idevento,
            idrecinto,
            estado
        )
        VALUES (
            (clock_timestamp() AT TIME ZONE 'America/El_Salvador')::DATE - 1,
            '12:00',
            v_idevento,
            v_idrecinto,
            'programada'
        )
        RETURNING idfuncion INTO v_idfuncion;

        INSERT INTO tarifa (
            precio,
            estado,
            idfuncion,
            idasiento
        )
        VALUES (
            30.00,
            'disponible',
            v_idfuncion,
            v_idasiento
        )
        RETURNING idtarifa INTO v_idtarifa;

        INSERT INTO pago (
            fecha,
            hora,
            montototal,
            metodopago,
            estado,
            idusuario
        )
        VALUES (
            (clock_timestamp() AT TIME ZONE 'America/El_Salvador')::DATE,
            (clock_timestamp() AT TIME ZONE 'America/El_Salvador')::TIME,
            30.00,
            'tarjeta',
            'aprobado',
            v_idusuario
        )
        RETURNING idpago INTO v_idpago;

        INSERT INTO tique (
            codigo,
            preciopagado,
            estado,
            idprecio,
            idpago,
            idusuario
        )
        VALUES (
            'TE-DEMO-' ||
            SUBSTR(
                MD5(
                    random()::TEXT ||
                    clock_timestamp()::TEXT
                ),
                1,
                20
            ),
            30.00,
            'emitido',
            v_idtarifa,
            v_idpago,
            v_idusuario
        );

        RAISE EXCEPTION
        'PRUEBA FALLIDA: se permitio vender un tique pasado';

    EXCEPTION WHEN OTHERS THEN

        IF SQLERRM LIKE 'VENTA FUERA DE TIEMPO:%' THEN

            RAISE NOTICE
            'TRIGGER FUNCIONANDO: %',
            SQLERRM;

        ELSE
            RAISE;
        END IF;

    END;

END;
$demo$;


-- ============================================================
-- PASO 9. Verificar los triggers instalados
-- ============================================================

SELECT
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table = 'tique'
  AND trigger_name IN (
      'trg_auditoria_ventas',
      'trg_validar_horario_venta'
  )
ORDER BY trigger_name;


-- ============================================================
-- PASO 10. Consultar el historial de auditoria
-- ============================================================

SELECT
    idauditoria,
    idtique,
    fecha_venta,
    idusuario,
    usuario_bd,
    idpago,
    idfuncion
FROM auditoria_ventas
ORDER BY idauditoria DESC;
