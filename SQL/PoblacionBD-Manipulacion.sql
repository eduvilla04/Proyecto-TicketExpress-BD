
-- =============================================================
-- I. INSERCIONES (INSERT)
-- Orden de dependencias: categoria, organizador, recinto, usuario,
-- evento, zona, funcion, asiento, pago, tarifa, tique.
-- =============================================================

-- CATEGORIA: 15 registros iniciales
INSERT INTO categoria (id_categoria, nombre)
VALUES
    (1001, 'Conciertos'),
    (1002, 'Teatro'),
    (1003, 'Futbol'),
    (1004, 'Baloncesto'),
    (1005, 'Conferencias'),
    (1006, 'Ferias'),
    (1007, 'Danza'),
    (1008, 'Cine'),
    (1009, 'Comedia'),
    (1010, 'Festivales'),
    (1011, 'Exposiciones'),
    (1012, 'Tecnologia'),
    (1013, 'Motociclismo'),
    (1014, 'Talleres'),
    (1015, 'Categoria de prueba');

select * from categoria c;

-- ORGANIZADOR: 15 registros iniciales
INSERT INTO organizador (id_organizador, nombre, telefono, correo)
VALUES
    (2001, 'Producciones Aurora', '22221001', 'organizador01@eventos.com'),
    (2002, 'Escena Viva', '22221002', 'organizador02@eventos.com'),
    (2003, 'Deportes Capital', '22221003', 'organizador03@eventos.com'),
    (2004, 'Liga Canastas', '22221004', 'organizador04@eventos.com'),
    (2005, 'Foro Empresarial', '22221005', 'organizador05@eventos.com'),
    (2006, 'Cultura Abierta', '22221006', 'organizador06@eventos.com'),
    (2007, 'Movimiento Artistico', '22221007', 'organizador07@eventos.com'),
    (2008, 'Cine Independiente SV', '22221008', 'organizador08@eventos.com'),
    (2009, 'Risas Producciones', '22221009', 'organizador09@eventos.com'),
    (2010, 'Festivales del Pacifico', '22221010', 'organizador10@eventos.com'),
    (2011, 'Galeria Abierta', '22221011', 'organizador11@eventos.com'),
    (2012, 'Innovacion Digital', '22221012', 'organizador12@eventos.com'),
    (2013, 'Moto Eventos', '22221013', 'organizador13@eventos.com'),
    (2014, 'Formacion Creativa', '22221014', 'organizador14@eventos.com'),
    (2015, 'Organizador de prueba', '22221015', 'organizador15@eventos.com');

select * from organizador;

-- RECINTO: 15 registros iniciales
INSERT INTO recinto (id_recinto, nombre, ubicacion)
VALUES
    (3001, 'Museo de Arte de El Salvador (MARTE)', 'San Salvador'),
    (3002, 'BeSport', 'Nuevo Cuscatlan, La Libertad'),
    (3003, 'Estadio Cuscatlan', 'San Salvador'),
    (3004, 'Gimnasio Nacional Jose Adolfo Pineda', 'San Salvador'),
    (3005, 'Estadio Jorge Magico Gonzalez', 'San Salvador'),
    (3006, 'Plaza Gerardo Barrios', 'San Salvador'),
    (3007, 'Teatro Nacional de San Salvador', 'San Salvador'),
    (3008, 'Teatro Presidente', 'San Salvador'),
    (3009, 'Teatro Luis Poma', 'San Salvador'),
    (3010, 'Complejo Deportivo Cuscatlan', 'San Salvador'),
    (3011, 'Biblioteca Nacional de El Salvador (BINAES)', 'San Salvador'),
    (3012, 'Anfiteatro del Parque Cuscatlan', 'San Salvador'),
    (3013, 'Autodromo Internacional El Jabali', 'Nuevo Sitio del Nino, La Libertad'),
    (3014, 'Teatro Nacional de Santa Ana', 'Santa Ana'),
    (3015, 'Hotel Sheraton Presidente', 'San Salvador');

select * from recinto r;

-- USUARIO: 15 registros iniciales
INSERT INTO usuario (id_usuario, nombre, apellido, telefono, correo)
VALUES
    (4001, 'Ana', 'Martinez', '70001001', 'cliente01@correo.com'),
    (4002, 'Carlos', 'Lopez', '70001002', 'cliente02@correo.com'),
    (4003, 'Sofia', 'Hernandez', '70001003', 'cliente03@correo.com'),
    (4004, 'Diego', 'Ramirez', '70001004', 'cliente04@correo.com'),
    (4005, 'Valeria', 'Gomez', '70001005', 'cliente05@correo.com'),
    (4006, 'Mateo', 'Castro', '70001006', 'cliente06@correo.com'),
    (4007, 'Lucia', 'Rivera', '70001007', 'cliente07@correo.com'),
    (4008, 'Jose', 'Flores', '70001008', 'cliente08@correo.com'),
    (4009, 'Camila', 'Torres', '70001009', 'cliente09@correo.com'),
    (4010, 'Andres', 'Molina', '70001010', 'cliente10@correo.com'),
    (4011, 'Elena', 'Pineda', '70001011', 'cliente11@correo.com'),
    (4012, 'Luis', 'Herrera', '70001012', 'cliente12@correo.com'),
    (4013, 'Paula', 'Vasquez', '70001013', 'cliente13@correo.com'),
    (4014, 'Mario', 'Reyes', '70001014', 'cliente14@correo.com'),
    (4015, 'Usuario', 'Prueba', '70001015', 'cliente15@correo.com');

select * from usuario u;

-- EVENTO: 15 registros iniciales
-- Eventos simulados en recintos reales de El Salvador.
INSERT INTO evento (id_evento, nombre, descripcion, id_organizador, id_categoria)
VALUES
    (5001, 'Festival de Arte y Musica 2027', 'Presentaciones musicales y actividades artisticas en el Museo MARTE', 2001, 1001),
    (5002, 'Torneo de Futbol 7 BeSport', 'Competencia de futbol entre equipos aficionados', 2003, 1003),
    (5003, 'Final de la Copa Salvadorena', 'Partido de futbol entre los equipos finalistas del torneo', 2003, 1003),
    (5004, 'Liga Nacional de Baloncesto', 'Encuentro de equipos de baloncesto de primera division', 2004, 1004),
    (5005, 'Festival de Musica Urbana 2027', 'Concierto de artistas nacionales e internacionales', 2001, 1001),
    (5006, 'Feria Cultural del Centro Historico', 'Exhibicion de artesanias, libros y productos nacionales', 2006, 1006),
    (5007, 'Gala Nacional de Danza', 'Presentacion de grupos de danza clasica y contemporanea', 2007, 1007),
    (5008, 'Hamlet en Escena', 'Presentacion de la obra teatral clasica Hamlet', 2002, 1002),
    (5009, 'Noche de Comedia Salvadorena', 'Espectaculo de comedia con artistas nacionales', 2009, 1009),
    (5010, 'Torneo Deportivo Juvenil', 'Competencias de baloncesto entre equipos juveniles', 2004, 1004),
    (5011, 'Exposicion de Fotografia Salvadorena', 'Exhibicion de fotografias sobre la cultura nacional', 2011, 1011),
    (5012, 'Festival de Musica Independiente', 'Concierto al aire libre con bandas salvadorenas', 2001, 1001),
    (5013, 'Campeonato Nacional de Motovelocidad', 'Competencia de motocicletas en circuito de carreras', 2013, 1013),
    (5014, 'Festival de Teatro de Santa Ana', 'Presentacion de obras teatrales de artistas nacionales', 2002, 1002),
    (5015, 'Foro Empresarial El Salvador 2027', 'Conferencias sobre emprendimiento, negocios e innovacion', 2005, 1005);

select * from evento;

-- ZONA: 15 registros iniciales
INSERT INTO zona (id_zona, nombre, capacidad, id_recinto)
VALUES
    (6001, 'General', 150, 3001),
    (6002, 'VIP', 100, 3002),
    (6003, 'Preferencial', 250, 3003),
    (6004, 'Graderio', 120, 3004),
    (6005, 'Auditorio A', 90, 3005),
    (6006, 'Acceso General', 300, 3006),
    (6007, 'Plateas', 80, 3007),
    (6008, 'Sala Principal', 60, 3008),
    (6009, 'Sector Central', 100, 3009),
    (6010, 'Campo Abierto', 400, 3010),
    (6011, 'Galeria', 75, 3011),
    (6012, 'Conferencias', 100, 3012),
    (6013, 'Pista', 180, 3013),
    (6014, 'Salon A', 40, 3014),
    (6015, 'Zona de prueba', 20, 3001);

select * from zona z;

-- FUNCION: 15 registros iniciales
-- Cada funcion utiliza un recinto existente y una zona de ese recinto.
INSERT INTO funcion (id_funcion, fecha, hora, estado, id_evento, id_recinto)
VALUES
    (7001, '2027-01-15', '18:00', 'programada', 5001, 3001),
    (7002, '2027-01-20', '15:00', 'programada', 5002, 3002),
    (7003, '2027-02-05', '19:00', 'programada', 5003, 3003),
    (7004, '2027-02-12', '17:00', 'programada', 5004, 3004),
    (7005, '2027-02-20', '19:00', 'programada', 5005, 3005),
    (7006, '2027-03-06', '10:00', 'programada', 5006, 3006),
    (7007, '2027-03-13', '18:00', 'programada', 5007, 3007),
    (7008, '2027-03-20', '19:00', 'programada', 5008, 3008),
    (7009, '2027-04-03', '18:00', 'programada', 5009, 3009),
    (7010, '2027-04-10', '09:00', 'programada', 5010, 3010),
    (7011, '2027-04-17', '10:00', 'programada', 5011, 3011),
    (7012, '2027-04-24', '17:00', 'programada', 5012, 3012),
    (7013, '2027-05-08', '09:00', 'suspendida', 5013, 3013),
    (7014, '2027-05-15', '18:00', 'cancelada', 5014, 3014),
    (7015, '2027-05-22', '16:00', 'programada', 5015, 3001);

select * from funcion f;

-- ASIENTO: 15 registros iniciales
INSERT INTO asiento (id_asiento, numero, fila, id_zona)
VALUES
    (8001, 1, 'A', 6001),
    (8002, 2, 'A', 6001),
    (8003, 1, 'A', 6002),
    (8004, 2, 'A', 6002),
    (8005, 1, 'A', 6003),
    (8006, 2, 'A', 6003),
    (8007, 1, 'A', 6004),
    (8008, 1, 'A', 6005),
    (8009, 1, 'A', 6006),
    (8010, 1, 'A', 6007),
    (8011, 1, 'A', 6008),
    (8012, 1, 'A', 6009),
    (8013, 1, 'A', 6010),
    (8014, 1, 'A', 6011),
    (8015, 1, 'A', 6012);

	select * from asiento a;

-- PAGO: 12 registros iniciales
INSERT INTO pago (id_pago, fecha_pago, monto_total, metodo_pago, estado_pago, id_usuario)
VALUES
    (9001, '2026-10-01 10:30:00', 170, 'efectivo', 'aprobado', 4001),
    (9002, '2026-10-02 10:30:00', 90, 'tarjeta', 'aprobado', 4002),
    (9003, '2026-10-03 10:30:00', 70, 'transferencia', 'aprobado', 4003),
    (9004, '2026-10-04 10:30:00', 25, 'efectivo', 'aprobado', 4004),
    (9005, '2026-10-05 10:30:00', 60, 'tarjeta', 'aprobado', 4005),
    (9006, '2026-10-06 10:30:00', 15, 'transferencia', 'aprobado', 4006),
    (9007, '2026-10-07 10:30:00', 30, 'efectivo', 'aprobado', 4007),
    (9008, '2026-10-08 10:30:00', 20, 'tarjeta', 'aprobado', 4008),
    (9009, '2026-10-09 10:30:00', 25, 'transferencia', 'aprobado', 4009),
    (9010, '2026-10-10 10:30:00', 100, 'efectivo', 'aprobado', 4010),
    (9011, '2026-10-11 10:30:00', 40, 'tarjeta', 'aprobado', 4011),
    (9012, '2026-10-12 10:30:00', 55, 'transferencia', 'aprobado', 4012);

select * from pago p;

-- TARIFA: 15 registros iniciales
INSERT INTO tarifa (id_tarifa, precio, id_funcion, id_zona)
VALUES
    (10001, 85, 7001, 6001),
    (10002, 45, 7002, 6002),
    (10003, 35, 7003, 6003),
    (10004, 25, 7004, 6004),
    (10005, 60, 7005, 6005),
    (10006, 15, 7006, 6006),
    (10007, 30, 7007, 6007),
    (10008, 20, 7008, 6008),
    (10009, 25, 7009, 6009),
    (10010, 100, 7010, 6010),
    (10011, 40, 7011, 6011),
    (10012, 55, 7012, 6012),
    (10013, 75, 7013, 6013),
    (10014, 25, 7014, 6014),
    (10015, 90, 7015, 6001);

select * from tarifa t;

-- TIQUE: 15 registros iniciales
INSERT INTO tique (codigo_tique, precio, id_pago, id_asiento, id_funcion, id_tarifa)
VALUES
    ('TEX-2027-0001', 85, 9001, 8001, 7001, 10001),
    ('TEX-2027-0002', 85, 9001, 8002, 7001, 10001),
    ('TEX-2027-0003', 45, 9002, 8003, 7002, 10002),
    ('TEX-2027-0004', 45, 9002, 8004, 7002, 10002),
    ('TEX-2027-0005', 35, 9003, 8005, 7003, 10003),
    ('TEX-2027-0006', 35, 9003, 8006, 7003, 10003),
    ('TEX-2027-0007', 25, 9004, 8007, 7004, 10004),
    ('TEX-2027-0008', 60, 9005, 8008, 7005, 10005),
    ('TEX-2027-0009', 15, 9006, 8009, 7006, 10006),
    ('TEX-2027-0010', 30, 9007, 8010, 7007, 10007),
    ('TEX-2027-0011', 20, 9008, 8011, 7008, 10008),
    ('TEX-2027-0012', 25, 9009, 8012, 7009, 10009),
    ('TEX-2027-0013', 100, 9010, 8013, 7010, 10010),
    ('TEX-2027-0014', 40, 9011, 8014, 7011, 10011),
    ('TEX-2027-0015', 55, 9012, 8015, 7012, 10012);

select * from tique;

-- =============================================================
-- II. ACTUALIZACIONES: 10 UPDATE
-- Cada UPDATE va precedido por SELECT con EXACTAMENTE el mismo WHERE.
-- =============================================================

-- 1. Ajustar nombre de categoria
SELECT * FROM categoria WHERE id_categoria = 1001;
UPDATE categoria SET nombre = 'Conciertos y musica' WHERE id_categoria = 1001;

-- 2. Corregir telefono de organizador
SELECT * FROM organizador WHERE id_organizador = 2001;
UPDATE organizador SET telefono = '22229999' WHERE id_organizador = 2001;

-- 3. Precisar ubicacion del recinto
SELECT * FROM recinto WHERE id_recinto = 3001;
UPDATE recinto SET ubicacion = 'Colonia San Benito, San Salvador' WHERE id_recinto = 3001;

-- 4. Actualizar telefono de cliente
SELECT * FROM usuario WHERE id_usuario = 4001;
UPDATE usuario SET telefono = '70009999' WHERE id_usuario = 4001;

-- 5. Mejorar descripcion del evento
SELECT * FROM evento WHERE id_evento = 5001;
UPDATE evento SET descripcion = 'Festival de arte y musica con artistas nacionales e invitados especiales' WHERE id_evento = 5001;

-- 6. Corregir capacidad de zona
SELECT * FROM zona WHERE id_zona = 6001;
UPDATE zona SET capacidad = 180 WHERE id_zona = 6001;

-- 7. Suspender funcion sin tiques vendidos
SELECT * FROM funcion WHERE id_funcion = 7015;
UPDATE funcion SET estado = 'suspendida' WHERE id_funcion = 7015;

-- 8. Corregir numeracion de un asiento
SELECT * FROM asiento WHERE id_asiento = 8001;
UPDATE asiento SET numero = 11 WHERE id_asiento = 8001;

-- 9. Corregir metodo de pago registrado
SELECT * FROM pago WHERE id_pago = 9001;
UPDATE pago SET metodo_pago = 'tarjeta' WHERE id_pago = 9001;

-- 10. Actualizar tarifa de funcion sin ventas
SELECT * FROM tarifa WHERE id_tarifa = 10015;
UPDATE tarifa SET precio = 95.00 WHERE id_tarifa = 10015;

-- =============================================================
-- III. ELIMINACIONES: 5 DELETE
-- Solo registros de prueba sin referencias en otras tablas.
-- Cada DELETE va precedido por SELECT con EXACTAMENTE el mismo WHERE.
-- =============================================================

-- 1. Eliminar categoria de prueba
SELECT * FROM categoria WHERE id_categoria = 1015;
DELETE FROM categoria WHERE id_categoria = 1015;

-- 2. Eliminar organizador de prueba
SELECT * FROM organizador WHERE id_organizador = 2015;
DELETE FROM organizador WHERE id_organizador = 2015;

-- 3. Eliminar recinto sin funciones ni zonas registradas
SELECT * FROM recinto WHERE id_recinto = 3015;
DELETE FROM recinto WHERE id_recinto = 3015;

-- 4. Eliminar usuario de prueba
SELECT * FROM usuario WHERE id_usuario = 4015;
DELETE FROM usuario WHERE id_usuario = 4015;

-- 5. Eliminar zona de prueba (no tiene asientos ni tarifas)
SELECT * FROM zona WHERE id_zona = 6015;
DELETE FROM zona WHERE id_zona = 6015;

-- =============================================================
-- IV. CONSULTAS DE VERIFICACION (SELECT)
-- =============================================================
-- Conteos finales: 14 categorias, 14 organizadores, 14 recintos,
-- 14 usuarios, 15 eventos, 14 zonas, 15 funciones, 15 asientos,
-- 12 pagos, 15 tarifas y 15 tiques.
SELECT 'categoria' AS tabla, COUNT(*) AS total FROM categoria
UNION ALL SELECT 'organizador', COUNT(*) FROM organizador
UNION ALL SELECT 'recinto', COUNT(*) FROM recinto
UNION ALL SELECT 'usuario', COUNT(*) FROM usuario
UNION ALL SELECT 'evento', COUNT(*) FROM evento
UNION ALL SELECT 'zona', COUNT(*) FROM zona
UNION ALL SELECT 'funcion', COUNT(*) FROM funcion
UNION ALL SELECT 'asiento', COUNT(*) FROM asiento
UNION ALL SELECT 'pago', COUNT(*) FROM pago
UNION ALL SELECT 'tarifa', COUNT(*) FROM tarifa
UNION ALL SELECT 'tique', COUNT(*) FROM tique;

-- Verificar si se conservaron los registros de prueba (debe devolver 0 en cada consulta).
SELECT * FROM categoria WHERE id_categoria = 1015;
SELECT * FROM organizador WHERE id_organizador = 2015;
SELECT * FROM recinto WHERE id_recinto = 3015;
SELECT * FROM usuario WHERE id_usuario = 4015;
SELECT * FROM zona WHERE id_zona = 6015;

-- Verificar datos modificados.
SELECT * FROM categoria WHERE id_categoria = 1001;
SELECT * FROM funcion WHERE id_funcion = 7015;
SELECT * FROM tarifa WHERE id_tarifa = 10015;

-- Verificar total cobrado en cada pago vs. suma de sus tiques.
-- Los dos valores deben coincidir en las 12 filas.
SELECT p.id_pago, p.monto_total, SUM(t.precio) AS total_tiques
FROM pago AS p
JOIN tique AS t ON t.id_pago = p.id_pago
WHERE p.id_pago BETWEEN 9001 AND 9012
GROUP BY p.id_pago, p.monto_total
ORDER BY p.id_pago;

-- No debe haber ventas para funciones suspendidas o canceladas (0 filas).
SELECT t.codigo_tique, f.id_funcion, f.estado
FROM tique AS t
JOIN funcion AS f ON f.id_funcion = t.id_funcion
WHERE f.estado IN ('suspendida', 'cancelada');
