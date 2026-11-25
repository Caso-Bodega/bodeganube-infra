#!/usr/bin/env bash
# Une ESTE nodo a un Swarm existente, como worker o como manager.
#
#   bash unir-nodo.sh <worker|manager> <TOKEN> <IP_PRIVADA_DEL_MANAGER>
#
# El token lo entrega init-manager.sh (o, en el manager: docker swarm join-token -q worker).
# Si el nodo ya pertenece a un Swarm no hace nada.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Uso: bash unir-nodo.sh <worker|manager> <TOKEN> <IP_PRIVADA_DEL_MANAGER>" >&2
  exit 1
fi
ROL="$1"
TOKEN="$2"
IP_MANAGER="$3"

if [ "$ROL" != "worker" ] && [ "$ROL" != "manager" ]; then
  echo "El rol debe ser worker o manager" >&2
  exit 1
fi

if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" = "active" ]; then
  echo "Este nodo ya pertenece a un Swarm; no se vuelve a unir."
  exit 0
fi

echo "Uniendo este nodo como $ROL al manager $IP_MANAGER:2377 ..."
docker swarm join --token "$TOKEN" "$IP_MANAGER:2377"
echo "Listo. En el manager, 'docker node ls' muestra el nuevo nodo."
