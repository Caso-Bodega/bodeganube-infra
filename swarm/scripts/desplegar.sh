#!/usr/bin/env bash
# Despliega (o actualiza) el stack bodeganube en el Swarm. Se corre en un nodo MANAGER.
#
#   bash swarm/scripts/desplegar.sh
#
# 1. Crea los secretos que falten (crear-secretos.sh).
# 2. docker stack deploy con docker-compose.swarm.yml (las imagenes vienen de ghcr.io).
# 3. Espera hasta que todos los servicios tengan sus replicas corriendo (maximo 6 minutos).
set -euo pipefail

STACK="${STACK:-bodeganube}"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$RAIZ"

bash swarm/scripts/crear-secretos.sh
# El archivo con valores ya no se necesita: los secretos quedaron cifrados en el Swarm
rm -f .secretos.env

echo
echo "Desplegando el stack $STACK ..."
docker stack deploy -c docker-compose.swarm.yml --with-registry-auth "$STACK"

echo
echo "Esperando que todas las replicas esten corriendo ..."
for intento in $(seq 1 72); do
  pendientes="$(docker stack services "$STACK" --format '{{.Replicas}}' | awk -F'[/ ]' '$1 != $2' | wc -l)"
  if [ "$pendientes" -eq 0 ]; then
    echo "Todos los servicios estan arriba (intento $intento)."
    break
  fi
  sleep 5
done

docker stack services "$STACK"
if [ "$pendientes" -ne 0 ]; then
  echo "Hay servicios que no alcanzaron sus replicas. Revisa: docker service ps ${STACK}_<servicio> --no-trunc" >&2
  exit 1
fi
