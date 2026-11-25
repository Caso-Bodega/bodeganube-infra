#!/usr/bin/env bash
# Crea en el Swarm los secretos que usa el stack (se corre en un nodo MANAGER).
#
# Los valores se toman de variables de entorno o del archivo .secretos.env en la raiz del repositorio.
# Si una variable no viene, se genera un valor aleatorio. Un secreto que ya existe NO se modifica
# (Swarm no permite cambiar un secreto en uso).
#
#   DB_PASSWORD        contrasena de PostgreSQL
#   JWT_SECRET         clave HMAC que comparten ms-autenticacion y ms-gateway (minimo 32 caracteres)
#   WEBHOOK_API_KEY    clave M2M entre la Lambda procesadora y el gateway (debe ser la misma de la Lambda)
#   OPERARIO_PASSWORD  contrasena del usuario de demostracion "operario"
#   COMERCIO_PASSWORD  contrasena del usuario de demostracion "tienda1"
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -f "$RAIZ/.secretos.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$RAIZ/.secretos.env"
  set +a
fi

aleatorio() { head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c "$1"; }

crear() {
  local nombre="bodeganube_$1" valor="$2"
  if docker secret inspect "$nombre" > /dev/null 2>&1; then
    echo "  = $nombre ya existe (no se modifica)"
  else
    printf '%s' "$valor" | docker secret create "$nombre" - > /dev/null
    echo "  + $nombre creado"
  fi
}

echo "Secretos del stack bodeganube:"
crear db_password       "${DB_PASSWORD:-$(aleatorio 24)}"
crear jwt_secret        "${JWT_SECRET:-$(aleatorio 48)}"
crear webhook_api_key   "${WEBHOOK_API_KEY:-$(aleatorio 32)}"
crear operario_password "${OPERARIO_PASSWORD:-Operario.2026}"
crear comercio_password "${COMERCIO_PASSWORD:-Tienda1.2026}"
