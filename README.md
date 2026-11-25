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
├── docker-compose.swarm.yml    el mismo sistema para Docker Swarm: replicas, secretos, red overlay
├── postgres/01-crear-bases.sql una base de datos por microservicio (Database per Service)
├── swarm/scripts/              iniciar el manager, unir nodos, crear secretos, desplegar, escalar, estado
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

## 2. Clúster Docker Swarm

### Arquitectura
```
                          Internet (Amazon API Gateway, GitHub Actions)
                                         │  :8080
          ┌──────────────────────────────┼──────────────────────────────┐
          │ routing mesh: el 8080 responde en cualquier nodo y Swarm lo │
          │ envia a una replica sana del gateway                        │
  ┌───────▼────────┐            ┌────────▼───────┐            ┌─────────▼──────┐
  │ manager-1      │            │ worker-1       │            │ worker-2       │
  │ (Leader)       │◄──2377────►│                │◄──7946────►│                │
  │ postgres       │            │ ms-gateway     │            │ ms-gateway     │
  │ ms-inventario  │            │ ms-ordenes     │            │ ms-ordenes     │
  │ ms-picking     │            │ ms-autentic.   │            │ ms-inventario  │
  └────────────────┘            └────────────────┘            └────────────────┘
          └──────────── red overlay "backend" (VXLAN 4789/udp) ────────────┘
```
Las réplicas se reparten solas entre los nodos (`placement.preferences: spread`). Solo el gateway publica un
puerto; los microservicios y PostgreSQL quedan en la red overlay interna.

### `docker-compose.swarm.yml`
Es un archivo Compose (formato 3.8) que `docker stack deploy` entiende. Cada servicio tiene:
- `image`: la imagen que publica su pipeline en GitHub Container Registry (`ghcr.io/caso-bodega/<servicio>`).
- `deploy.replicas`: cuántas copias corren (gateway 2, ordenes 2, inventario 2, autenticación 1, picking 1).
- `deploy.update_config`: actualización de a una réplica, levantando primero la nueva (`start-first`) y volviendo
  atrás sola si no queda healthy (`failure_action: rollback`).
- `deploy.restart_policy`: si una réplica se cae, Swarm la levanta de nuevo.
- `deploy.resources`: límites y reservas de CPU y memoria por réplica.
- `secrets`: contraseñas y claves como secretos de Swarm (cifrados), montados en `/run/secrets`.
- `networks: backend`: red overlay que une los contenedores de todos los nodos.

### Scripts (`swarm/scripts`)

| Script | Dónde se corre | Qué hace |
|---|---|---|
| `init-manager.sh <ip-privada>` | manager | `docker swarm init` y muestra los comandos para unir nodos |
| `unir-nodo.sh <worker\|manager> <token> <ip-manager>` | nodo nuevo | `docker swarm join` |
| `crear-secretos.sh` | manager | crea los 5 secretos del stack (los que falten) |
| `desplegar.sh` | manager | crea secretos, `docker stack deploy` y espera que todas las réplicas estén arriba |
| `escalar.sh <servicio> <n>` | manager | `docker service scale` y muestra en qué nodo quedó cada réplica |
| `estado.sh` | manager | nodos, servicios y réplicas por nodo |

Todos se pueden volver a correr sin romper nada (si el nodo ya está en el Swarm o el secreto ya existe, no lo
repiten).

### Armar el clúster a mano
El pipeline `infra.yml` hace todo esto solo; a mano son estos pasos (por SSH en cada instancia):
```bash
# 1. En el MANAGER (con el repositorio copiado en ~/bodeganube)
bash ~/bodeganube/swarm/scripts/init-manager.sh <IP_PRIVADA_DEL_MANAGER>
#    -> imprime: bash unir-nodo.sh worker <TOKEN> <IP_PRIVADA_DEL_MANAGER>

# 2. En cada WORKER
bash unir-nodo.sh worker <TOKEN> <IP_PRIVADA_DEL_MANAGER>

# 3. De vuelta en el MANAGER
cd ~/bodeganube && WEBHOOK_API_KEY=<clave> bash swarm/scripts/desplegar.sh
bash swarm/scripts/estado.sh
```

### Añadir un nodo worker
1. Crear la instancia (otra EC2 con Docker en el mismo grupo de seguridad, para que tenga abiertos 2377, 7946 y
   4789).
2. En el manager: `docker swarm join-token -q worker` (entrega el token).
3. En el nodo nuevo: `bash unir-nodo.sh worker <TOKEN> <IP_PRIVADA_DEL_MANAGER>`.
4. En el manager: `docker node ls` lo muestra `Ready`. Las réplicas nuevas (o las que se reprogramen) ya pueden
   correr ahí; para repartir las actuales: `docker service update --force bodeganube_ms-ordenes`.

### Añadir un nodo manager
Los managers mantienen el estado del clúster con Raft y necesitan mayoría: con 3 managers el clúster sigue
administrable aunque caiga uno. Se usa siempre un número impar (1, 3 o 5).
1. En un manager: `docker swarm join-token -q manager`.
2. En el nodo nuevo: `bash unir-nodo.sh manager <TOKEN> <IP_PRIVADA_DEL_MANAGER>`.
3. También se puede ascender un worker existente: `docker node promote bodeganube-worker-1`
   (y bajarlo con `docker node demote`).
4. Para sacar un nodo sin cortar servicios: `docker node update --availability drain <nodo>` (Swarm mueve sus
   réplicas a otros nodos) y después `docker swarm leave` en ese nodo.

### Escalar
```bash
bash swarm/scripts/escalar.sh ms-ordenes 4    # hacia arriba: 2 replicas nuevas, repartidas entre los nodos
bash swarm/scripts/escalar.sh ms-ordenes 2    # hacia abajo: Swarm detiene 2 replicas
```
El gateway llama a `http://ms-ordenes:8082`, una IP virtual que Swarm balancea entre todas las réplicas
sanas, así que las nuevas empiezan a recibir tráfico apenas quedan healthy, sin tocar la configuración.

### Actualizar sin cortes
El pipeline de cada microservicio hace `docker service update --image ghcr.io/caso-bodega/<servicio>:sha-<commit>`.
Con `order: start-first` Swarm levanta la réplica nueva, espera su healthcheck, recién entonces baja la vieja y
pasa a la siguiente. En la prueba local se hicieron 90 peticiones durante la actualización de ms-inventario y
las 90 respondieron 200. Si la nueva versión no queda healthy en 60 s, Swarm vuelve sola a la anterior.

### Decisiones técnicas
| Decisión | Escalabilidad | Disponibilidad | Mantenibilidad |
|---|---|---|---|
| 3 nodos en instancias separadas (1 manager + 2 workers) | se suma capacidad agregando workers | si cae un worker, Swarm reprograma sus réplicas en los otros | todos los nodos se crean igual con CloudFormation |
| 2 réplicas en el camino crítico (gateway, ordenes, inventario) y 1 en el resto | se escala solo lo que recibe más carga | ninguna caída de una réplica corta la venta | réplicas declaradas en un solo archivo |
| `spread: node.id` | aprovecha la CPU y memoria de todos los nodos | las 2 réplicas de un servicio no quedan en el mismo nodo | Swarm decide la ubicación, no hay que fijarla a mano |
| Rolling update `start-first` + healthcheck + rollback | — | despliegues sin corte | una versión mala vuelve atrás sola |
| `restart_policy: any` | — | autorreparación de contenedores caídos | — |
| Límites y reservas de CPU/memoria | el scheduler ubica réplicas donde hay recursos | un servicio no ahoga a los demás | consumo predecible por réplica |
| Solo el gateway publica un puerto (routing mesh) | entra por cualquier nodo | si cae el nodo de una réplica, el 8080 sigue respondiendo en los otros | una sola puerta que proteger |
| Secretos de Swarm en vez de variables de entorno | — | — | las claves no quedan en el repositorio ni en `docker inspect` |
| Imágenes inmutables por commit (`sha-<commit>`) | — | se puede volver a cualquier versión | se sabe exactamente qué código corre |
| PostgreSQL fijado al manager con volumen | — | los datos sobreviven a reinicios | **limitación**: es un punto único; en producción se usaría Amazon RDS Multi-AZ |
| 1 solo manager | — | **limitación**: si cae, los servicios siguen corriendo pero no se puede administrar; para alta disponibilidad se agregan 2 managers (ver arriba) | — |

## Ramas
`main` tiene la versión entregada, `develop` integra el trabajo en curso y cada cambio entra desde una rama
`feature/...` con un Pull Request hacia `develop`.
