# bodeganube-infra

Infraestructura y despliegue del caso **BodegaNube** (JVY0101): Docker Compose para correr todo el sistema en
un PC, el clúster **Docker Swarm** en AWS (EC2) y las pruebas de extremo a extremo.

## Repositorios del sistema

| Repositorio | Qué contiene |
|---|---|
| [ms-autenticacion](https://github.com/Caso-Bodega/ms-autenticacion) | Usuarios, login y emisión de JWT |
| [ms-gateway](https://github.com/Caso-Bodega/ms-gateway) | Spring Cloud Gateway: JWT, roles y API key del webhook |
| [ms-ordenes](https://github.com/Caso-Bodega/ms-ordenes) | Órdenes, idempotencia y reserva de stock |
| [ms-inventario](https://github.com/Caso-Bodega/ms-inventario) | Catálogo y stock |
| [ms-picking-despacho](https://github.com/Caso-Bodega/ms-picking-despacho) | Picking, despacho y tracking |
| [bodeganube-serverless](https://github.com/Caso-Bodega/bodeganube-serverless) | Amazon API Gateway, cola SQS y funciones Lambda |
| **bodeganube-infra** (este) | Docker Compose, Docker Swarm, EC2 y pruebas E2E |
| [doc](https://github.com/Caso-Bodega/doc) | Documentación del equipo y uso de IA |

## Estructura
```
bodeganube-infra
├── docker-compose.yml          todo el sistema en local (construye las imagenes desde cada repositorio)
├── postgres/01-crear-bases.sql una base de datos por microservicio (Database per Service)
└── scripts/actualizar-credenciales-aws.ps1   copia las credenciales del Learner Lab a los secretos de GitHub
```

## 1. Todo el sistema en local con Docker Compose
Requisitos: Docker Desktop y los repositorios clonados uno al lado del otro en la misma carpeta (el
`docker-compose.yml` construye cada imagen desde `../ms-<servicio>`).

```powershell
cd bodeganube-infra
docker compose up -d --build     # construye las 5 imagenes e inicia 6 contenedores
docker compose ps                # todos deben quedar "healthy" (unos 30 segundos)
docker compose logs -f ms-ordenes
docker compose down              # detiene todo; con -v borra tambien la base de datos
```

| Contenedor | Puerto en tu PC | Para probar |
|---|---|---|
| ms-gateway | 8080 | `postman/ms-gateway.postman_collection.json` (flujo completo con JWT) |
| ms-autenticacion | 8081 | su colección de Postman |
| ms-ordenes | 8082 | su colección (necesita ms-inventario arriba) |
| ms-inventario | 8083 | su colección |
| ms-picking-despacho | 8084 | su colección |
| postgres | no se publica | crea las 4 bases con `postgres/01-crear-bases.sql` |

Usuarios de prueba: `operario` / `Operario.2026` y `tienda1` / `Tienda1.2026` (comercio `comercio-123`).
Si el puerto 8080 está ocupado en tu PC: `$env:GATEWAY_PUERTO=18080; docker compose up -d`.

## Ramas
`main` tiene la versión entregada, `develop` integra el trabajo en curso y cada cambio entra desde una rama
`feature/...` con un Pull Request hacia `develop`.
