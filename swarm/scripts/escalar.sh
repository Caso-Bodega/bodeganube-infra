#!/usr/bin/env bash
# Cambia el numero de replicas de un servicio del stack (escalado horizontal). Se corre en un MANAGER.
#
#   bash swarm/scripts/escalar.sh ms-ordenes 4     # escala hacia arriba
#   bash swarm/scripts/escalar.sh ms-ordenes 2     # escala hacia abajo
#
# Swarm reparte las nuevas replicas entre los nodos y el balanceo interno las empieza a usar apenas
# quedan healthy; al bajar, detiene replicas sin cortar el servicio.
set -euo pipefail

STACK="${STACK:-bodeganube}"
if [ "$#" -ne 2 ]; then
  echo "Uso: bash escalar.sh <servicio> <replicas>   (ej: bash escalar.sh ms-ordenes 4)" >&2
  exit 1
fi

docker service scale "${STACK}_$1=$2"
echo
docker service ps "${STACK}_$1" --filter desired-state=running --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'
