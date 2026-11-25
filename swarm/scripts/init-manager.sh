#!/usr/bin/env bash
# Inicializa Docker Swarm en el nodo MANAGER (se corre una sola vez, en el manager).
#
#   bash swarm/scripts/init-manager.sh <IP_PRIVADA_DEL_MANAGER>
#
# Si el nodo ya es parte de un Swarm no hace nada (se puede correr de nuevo sin romper el cluster).
# Al final muestra los comandos para unir nodos worker y manager.
set -euo pipefail

IP_ANUNCIO="${1:-}"
if [ -z "$IP_ANUNCIO" ]; then
  # Sin parametro usa la IP privada de la maquina (en EC2, la de la VPC)
  IP_ANUNCIO="$(hostname -I | awk '{print $1}')"
fi

ESTADO="$(docker info --format '{{.Swarm.LocalNodeState}}')"
if [ "$ESTADO" = "active" ]; then
  echo "Este nodo ya pertenece a un Swarm; no se vuelve a inicializar."
else
  echo "Inicializando Swarm. El manager se anuncia en $IP_ANUNCIO:2377 ..."
  docker swarm init --advertise-addr "$IP_ANUNCIO"
fi

echo
echo "== Nodos del cluster =="
docker node ls
echo
echo "== Para unir un WORKER, en el nuevo nodo ejecuta: =="
echo "bash unir-nodo.sh worker $(docker swarm join-token -q worker) $IP_ANUNCIO"
echo
echo "== Para unir otro MANAGER (alta disponibilidad: usar 3 o 5 managers), ejecuta: =="
echo "bash unir-nodo.sh manager $(docker swarm join-token -q manager) $IP_ANUNCIO"
