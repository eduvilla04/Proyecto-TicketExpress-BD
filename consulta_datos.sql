--Registros por tabla 


SELECT 'categoria' AS tabla, COUNT(*) AS total FROM categoria
UNION ALL
SELECT 'recinto', COUNT(*) FROM recinto
UNION ALL
SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL
SELECT 'evento', COUNT(*) FROM evento
UNION ALL
SELECT 'asiento', COUNT(*) FROM asiento
UNION ALL
SELECT 'funcion', COUNT(*) FROM funcion
UNION ALL
SELECT 'pago', COUNT(*) FROM pago
UNION ALL
SELECT 'tarifa', COUNT(*) FROM tarifa
UNION ALL
SELECT 'tique', COUNT(*) FROM tique
ORDER BY tabla;

--1. ¿Cuál es el evento que tienen la mayor cantidad de tiques vendidos?

SELECT
    e.nombre AS evento,
    COUNT(t.idtique) AS tiques_vendidos
FROM evento e
INNER JOIN funcion f ON e.idevento = f.idevento
INNER JOIN tarifa ta ON f.idfuncion = ta.idfuncion
INNER JOIN tique t ON ta.idtarifa = t.idprecio
GROUP BY e.idevento, e.nombre
ORDER BY tiques_vendidos DESC
LIMIT 1;

--2. ¿Cuál es el ingreso total generado por cada evento?

SELECT
    e.nombre AS evento,
    COALESCE(SUM(t.preciopagado), 0) AS ingreso_total
FROM evento e
LEFT JOIN funcion f ON e.idevento = f.idevento
LEFT JOIN tarifa ta ON f.idfuncion = ta.idfuncion
LEFT JOIN tique t ON ta.idtarifa = t.idprecio
GROUP BY e.idevento, e.nombre
ORDER BY ingreso_total DESC;

--3. ¿Qué cliente ha comprado más tiques y cuántos ha adquirido?

SELECT
    u.nombre,
    u.apellido,
    COUNT(t.idtique) AS tiques_comprados
FROM usuario u
INNER JOIN pago p ON u.idusuario = p.idusuario
INNER JOIN tique t ON p.idpago = t.idpago
GROUP BY u.idusuario, u.nombre, u.apellido
ORDER BY tiques_comprados DESC
LIMIT 1;

--4. ¿Cuáles son las funciones cuya ocupación supera el 70% de los asientos disponibles?

SELECT
    f.idfuncion,
    e.nombre AS evento,
    COUNT(DISTINCT a.idasiento) AS asientos_disponibles,
    COUNT(DISTINCT t.idtique) AS tiques_vendidos,
    ROUND(
        COUNT(DISTINCT t.idtique) * 100.0 /
        COUNT(DISTINCT a.idasiento), 2
    ) AS porcentaje_ocupacion
FROM funcion f
INNER JOIN evento e ON f.idevento = e.idevento
INNER JOIN asiento a ON f.idrecinto = a.idrecinto
LEFT JOIN tarifa ta
    ON f.idfuncion = ta.idfuncion
    AND a.idasiento = ta.idasiento
LEFT JOIN tique t ON ta.idtarifa = t.idprecio
GROUP BY f.idfuncion, e.nombre
HAVING COUNT(DISTINCT t.idtique) >
       COUNT(DISTINCT a.idasiento) * 0.70
ORDER BY porcentaje_ocupacion DESC;

--5. ¿Existen funciones que no hayan registrado ninguna venta? Liste cuáles son.

SELECT
    f.idfuncion,
    e.nombre AS evento,
    f.fecha,
    f.hora,
    COUNT(t.idtique) AS tiques_vendidos
FROM funcion f
INNER JOIN evento e ON f.idevento = e.idevento
LEFT JOIN tarifa ta ON f.idfuncion = ta.idfuncion
LEFT JOIN tique t ON ta.idtarifa = t.idprecio
GROUP BY f.idfuncion, e.nombre, f.fecha, f.hora
HAVING COUNT(t.idtique) = 0
ORDER BY f.fecha, f.hora;






