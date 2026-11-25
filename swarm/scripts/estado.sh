#!/usr/bin/env bash
# Muestra el estado del cluster: nodos, servicios con sus replicas y en que nodo corre cada replica.
#
#   bash swarm/scripts/estado.sh
set -euo pipefail

STACK="${STACK:-bodeganube}"

echo "== Nodos =="
docker node ls
echo
echo "== Servicios del stack $STACK =="
docker stack services "$STACK"
echo
echo "== Replicas por nodo =="
docker stack ps "$STACK" --filter desired-state=running --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'
