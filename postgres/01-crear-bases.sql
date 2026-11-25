-- Database per Service: cada microservicio tiene su propia base de datos dentro del mismo PostgreSQL.
-- La imagen oficial de postgres ejecuta este archivo solo la primera vez que arranca con el volumen vacio.
CREATE DATABASE bodeganube_auth;
CREATE DATABASE bodeganube_ordenes;
CREATE DATABASE bodeganube_inventario;
CREATE DATABASE bodeganube_picking;
