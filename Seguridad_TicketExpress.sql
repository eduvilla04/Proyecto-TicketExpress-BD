-- TicketExpress+ - Seguridad y auditoria (entrega final)

BEGIN;
SET LOCAL search_path TO pg_catalog, public, pg_temp;

DO $$
BEGIN
    IF current_database() <> 'ticketexpress' OR current_user <> 'postgres' THEN
        RAISE EXCEPTION 'Ejecutar como postgres en la base ticketexpress';
    END IF;
    IF to_regclass('public.auditoria_ventas') IS NULL
       OR to_regprocedure('public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)') IS NULL
       OR to_regprocedure('public.cancelar_compra_tiques(bigint,bigint)') IS NULL
       OR to_regprocedure('public.consultar_asientos_disponibles(bigint)') IS NULL
       OR to_regprocedure('public.calcular_ingresos_evento(bigint)') IS NULL
       OR to_regprocedure('public.registrar_auditoria_venta()') IS NULL
       OR to_regprocedure('public.validar_horario_venta()') IS NULL THEN
        RAISE EXCEPTION 'Primero instalar los procedimientos, funciones y triggers anteriores';
    END IF;
END;
$$;

-- 1. Roles y usuarios. Conserva las contrasenas existentes.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_administrador') THEN
        CREATE ROLE rol_administrador NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_operador') THEN
        CREATE ROLE rol_operador NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_analista') THEN
        CREATE ROLE rol_analista NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_ticket') THEN
        CREATE ROLE admin_ticket LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'operador_ticket') THEN
        CREATE ROLE operador_ticket LOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analista_ticket') THEN
        CREATE ROLE analista_ticket LOGIN;
    END IF;
END;
$$;

ALTER ROLE rol_administrador NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_operador NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE rol_analista NOLOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE admin_ticket LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE operador_ticket LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE analista_ticket LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- Evitar que una membresia adicional invalide la politica.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_auth_members m
        JOIN pg_roles u ON u.oid = m.member
        JOIN pg_roles r ON r.oid = m.roleid
        WHERE u.rolname IN ('rol_administrador','rol_operador','rol_analista',
                            'admin_ticket','operador_ticket','analista_ticket')
          AND NOT ((u.rolname = 'admin_ticket' AND r.rolname = 'rol_administrador')
                OR (u.rolname = 'operador_ticket' AND r.rolname = 'rol_operador')
                OR (u.rolname = 'analista_ticket' AND r.rolname = 'rol_analista'))
    ) THEN
        RAISE EXCEPTION 'Hay membresias adicionales en los roles de TicketExpress; revisarlas antes de continuar';
    END IF;
END;
$$;

GRANT rol_administrador TO admin_ticket;
GRANT rol_operador TO operador_ticket;
GRANT rol_analista TO analista_ticket;

-- Permitir conexion a la base actual sin depender de su nombre.
DO $$
BEGIN
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO rol_administrador, rol_operador, rol_analista',
        current_database()
    );
END;
$$;

REVOKE CREATE ON SCHEMA public FROM PUBLIC, rol_administrador, rol_operador, rol_analista, admin_ticket, operador_ticket, analista_ticket;
GRANT USAGE ON SCHEMA public TO rol_administrador, rol_operador, rol_analista;

-- 2. Auditoria de operaciones sobre pago
CREATE TABLE IF NOT EXISTS public.auditoria_pago (
    idauditoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idpago BIGINT NOT NULL,
    operacion VARCHAR(10) NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    usuario_bd TEXT NOT NULL,
    datos_anteriores JSONB,
    datos_nuevos JSONB
);

-- Sin FK a pago para conservar el historial de registros eliminados.
CREATE OR REPLACE FUNCTION public.auditar_pago()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, pg_temp
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.auditoria_pago
            (idpago, operacion, usuario_bd, datos_nuevos)
        VALUES (NEW.idpago, TG_OP, SESSION_USER, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO public.auditoria_pago
            (idpago, operacion, usuario_bd, datos_anteriores, datos_nuevos)
        VALUES (OLD.idpago, TG_OP, SESSION_USER, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSE
        INSERT INTO public.auditoria_pago
            (idpago, operacion, usuario_bd, datos_anteriores)
        VALUES (OLD.idpago, TG_OP, SESSION_USER, to_jsonb(OLD));
        RETURN OLD;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_auditoria_pago ON public.pago;

CREATE TRIGGER trg_auditoria_pago
AFTER INSERT OR UPDATE OR DELETE ON public.pago
FOR EACH ROW
EXECUTE FUNCTION public.auditar_pago();

-- Conservar la auditoria de ventas anterior, registrando el login real.
CREATE OR REPLACE FUNCTION public.registrar_auditoria_venta()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO pg_catalog, public, pg_temp
AS $$
DECLARE
    v_idfuncion BIGINT;
BEGIN
    SELECT idfuncion INTO v_idfuncion
    FROM public.tarifa
    WHERE idtarifa = NEW.idprecio;

    INSERT INTO public.auditoria_ventas
        (idtique, fecha_venta, idusuario, usuario_bd, idpago, idfuncion)
    VALUES (NEW.idtique, NEW.fechaemision, NEW.idusuario,
            SESSION_USER, NEW.idpago, v_idfuncion);
    RETURN NEW;
END;
$$;

ALTER FUNCTION public.auditar_pago() OWNER TO postgres;
ALTER FUNCTION public.registrar_auditoria_venta() OWNER TO postgres;

-- Ninguno de los perfiles de trabajo debe ser propietario de las tablas.
-- Un propietario conserva facultades administrativas aun despues de REVOKE.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_roles r ON r.oid = c.relowner
        WHERE n.nspname = 'public'
          AND c.relname IN ('categoria','recinto','usuario','evento','asiento',
              'funcion','pago','tarifa','tique','auditoria_ventas','auditoria_pago')
          AND r.rolname IN ('rol_administrador','rol_operador','rol_analista',
              'admin_ticket','operador_ticket','analista_ticket')
    ) THEN
        RAISE EXCEPTION 'Un rol de trabajo es propietario de una tabla; revisar propietario antes de aplicar permisos';
    END IF;
END;
$$;

-- 3. Restablecer permisos de los roles de la actividad
-- Solo se afectan objetos de TicketExpress y los seis roles definidos.
REVOKE ALL PRIVILEGES ON TABLE
    public.categoria, public.recinto, public.usuario, public.evento,
    public.asiento, public.funcion, public.pago, public.tarifa,
    public.tique, public.auditoria_ventas, public.auditoria_pago
FROM PUBLIC, rol_administrador, rol_operador, rol_analista, admin_ticket, operador_ticket, analista_ticket;

-- Revocar tambien permisos por columna y sobre las secuencias del proyecto.
DO $$
DECLARE
    v_tabla TEXT;
    v_columnas TEXT;
    v_secuencia REGCLASS;
    v_columna_id TEXT;
BEGIN
    FOREACH v_tabla IN ARRAY ARRAY['categoria','recinto','usuario','evento',
        'asiento','funcion','pago','tarifa','tique','auditoria_ventas','auditoria_pago']
    LOOP
        SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
        INTO v_columnas
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = v_tabla;

        EXECUTE format('REVOKE ALL PRIVILEGES (%s) ON TABLE public.%I FROM PUBLIC, rol_administrador, rol_operador, rol_analista, admin_ticket, operador_ticket, analista_ticket',
            v_columnas, v_tabla);

        v_columna_id := CASE WHEN v_tabla IN ('auditoria_ventas','auditoria_pago')
                            THEN 'idauditoria' ELSE 'id' || v_tabla END;
        v_secuencia := pg_get_serial_sequence(format('public.%I', v_tabla), v_columna_id)::REGCLASS;
        IF v_secuencia IS NOT NULL THEN
            EXECUTE format('REVOKE ALL PRIVILEGES ON SEQUENCE %s FROM PUBLIC, rol_administrador, rol_operador, rol_analista, admin_ticket, operador_ticket, analista_ticket', v_secuencia);
            IF v_tabla NOT IN ('auditoria_ventas','auditoria_pago') THEN
                EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO rol_administrador', v_secuencia);
            END IF;
        END IF;
    END LOOP;
END;
$$;

-- 4. Administrador: gestionar datos, no administrar roles ni borrar tablas
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
    public.categoria, public.recinto, public.usuario, public.evento,
    public.asiento, public.funcion, public.pago, public.tarifa, public.tique
TO rol_administrador;

GRANT SELECT ON public.auditoria_ventas, public.auditoria_pago TO rol_administrador;

-- 5. Operador y analista: consultar el catalogo
GRANT SELECT ON TABLE
    public.categoria, public.recinto, public.evento,
    public.asiento, public.funcion, public.tarifa
TO rol_operador, rol_analista;

-- Operador: consultar solo los datos de clientes necesarios para vender
GRANT SELECT (idusuario, nombre, apellido, estado)
ON public.usuario TO rol_operador;
GRANT SELECT ON public.pago, public.tique TO rol_operador;

-- 6. Proteger las rutinas existentes y limitar su ejecucion
-- El propietario de estas rutinas debe ser un usuario de confianza.
ALTER PROCEDURE public.registrar_compra_tiques(BIGINT, BIGINT, BIGINT[], VARCHAR) OWNER TO postgres;
ALTER PROCEDURE public.cancelar_compra_tiques(BIGINT, BIGINT) OWNER TO postgres;
ALTER FUNCTION public.consultar_asientos_disponibles(BIGINT) OWNER TO postgres;
ALTER FUNCTION public.calcular_ingresos_evento(BIGINT) OWNER TO postgres;
ALTER FUNCTION public.validar_horario_venta() OWNER TO postgres;
ALTER FUNCTION public.validar_horario_venta() SET search_path TO pg_catalog, public, pg_temp;
ALTER PROCEDURE public.registrar_compra_tiques(BIGINT, BIGINT, BIGINT[], VARCHAR)
    SECURITY DEFINER;
ALTER PROCEDURE public.registrar_compra_tiques(BIGINT, BIGINT, BIGINT[], VARCHAR)
    SET search_path TO pg_catalog, public, pg_temp;
ALTER PROCEDURE public.cancelar_compra_tiques(BIGINT, BIGINT)
    SECURITY DEFINER;
ALTER PROCEDURE public.cancelar_compra_tiques(BIGINT, BIGINT)
    SET search_path TO pg_catalog, public, pg_temp;

ALTER FUNCTION public.consultar_asientos_disponibles(BIGINT) SECURITY DEFINER;
ALTER FUNCTION public.consultar_asientos_disponibles(BIGINT)
    SET search_path TO pg_catalog, public, pg_temp;
ALTER FUNCTION public.calcular_ingresos_evento(BIGINT) SECURITY DEFINER;
ALTER FUNCTION public.calcular_ingresos_evento(BIGINT)
    SET search_path TO pg_catalog, public, pg_temp;

REVOKE EXECUTE ON PROCEDURE
    public.registrar_compra_tiques(BIGINT, BIGINT, BIGINT[], VARCHAR),
    public.cancelar_compra_tiques(BIGINT, BIGINT)
FROM PUBLIC, rol_administrador, rol_operador, rol_analista, admin_ticket, operador_ticket, analista_ticket;

REVOKE EXECUTE ON FUNCTION
    public.consultar_asientos_disponibles(BIGINT),
    public.calcular_ingresos_evento(BIGINT),
    public.registrar_auditoria_venta(), public.validar_horario_venta(),
    public.auditar_pago()
FROM PUBLIC, rol_administrador, rol_operador, rol_analista, admin_ticket, operador_ticket, analista_ticket;

GRANT EXECUTE ON PROCEDURE
    public.registrar_compra_tiques(BIGINT, BIGINT, BIGINT[], VARCHAR),
    public.cancelar_compra_tiques(BIGINT, BIGINT)
TO rol_administrador, rol_operador;

GRANT EXECUTE ON FUNCTION
    public.consultar_asientos_disponibles(BIGINT),
    public.calcular_ingresos_evento(BIGINT)
TO rol_administrador, rol_operador, rol_analista;

-- Verificar permisos efectivos antes de confirmar los cambios.
DO $$
BEGIN
    IF NOT pg_has_role('admin_ticket','rol_administrador','USAGE')
       OR NOT pg_has_role('operador_ticket','rol_operador','USAGE')
       OR NOT pg_has_role('analista_ticket','rol_analista','USAGE')
       OR NOT has_table_privilege('admin_ticket','public.pago','SELECT')
       OR NOT has_table_privilege('admin_ticket','public.pago','INSERT')
       OR NOT has_table_privilege('admin_ticket','public.pago','UPDATE')
       OR NOT has_table_privilege('admin_ticket','public.pago','DELETE')
       OR NOT has_table_privilege('admin_ticket','public.auditoria_pago','SELECT')
       OR has_table_privilege('admin_ticket','public.auditoria_pago','INSERT,UPDATE,DELETE,TRUNCATE')
       OR NOT has_column_privilege('operador_ticket','public.usuario','idusuario','SELECT')
       OR has_column_privilege('operador_ticket','public.usuario','clave','SELECT')
       OR has_table_privilege('operador_ticket','public.pago','INSERT,UPDATE,DELETE,TRUNCATE')
       OR has_table_privilege('operador_ticket','public.auditoria_pago','SELECT')
       OR has_table_privilege('analista_ticket','public.pago','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
       OR has_any_column_privilege('analista_ticket','public.usuario','SELECT')
       OR has_table_privilege('analista_ticket','public.tique','SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
       OR has_table_privilege('analista_ticket','public.auditoria_pago','SELECT')
       OR has_schema_privilege('admin_ticket','public','CREATE')
       OR has_schema_privilege('operador_ticket','public','CREATE')
       OR has_schema_privilege('analista_ticket','public','CREATE')
       OR NOT has_function_privilege('operador_ticket','public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)','EXECUTE')
       OR NOT has_function_privilege('operador_ticket','public.cancelar_compra_tiques(bigint,bigint)','EXECUTE')
       OR has_function_privilege('analista_ticket','public.registrar_compra_tiques(bigint,bigint,bigint[],varchar)','EXECUTE')
       OR has_function_privilege('analista_ticket','public.cancelar_compra_tiques(bigint,bigint)','EXECUTE')
       OR NOT has_function_privilege('analista_ticket','public.calcular_ingresos_evento(bigint)','EXECUTE')
       OR NOT has_function_privilege('analista_ticket','public.consultar_asientos_disponibles(bigint)','EXECUTE') THEN
        RAISE EXCEPTION 'Los permisos efectivos no coinciden con la politica. Revisar propietarios y privilegios heredados';
    END IF;
END;
$$;

COMMIT;

-- 7. Verificar roles y membresias
SELECT u.rolname AS usuario, r.rolname AS rol
FROM pg_auth_members m
JOIN pg_roles u ON u.oid = m.member
JOIN pg_roles r ON r.oid = m.roleid
WHERE u.rolname IN ('admin_ticket', 'operador_ticket', 'analista_ticket')
ORDER BY u.rolname;

-- Verificar el trigger nuevo
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND trigger_name = 'trg_auditoria_pago'
ORDER BY event_manipulation;
