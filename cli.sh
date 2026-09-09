#!/usr/bin/env bash

REGISTRY_URL="https://raw.githubusercontent.com/TU_USUARIO/cli-packages/main/packages.json"
COMMAND="$1"
PKG_NAME="$2"

if [ "$COMMAND" = "install" ]; then
    if [ -z "$PKG_NAME" ]; then
        echo "Error: Especifica el nombre del paquete."
        exit 1
    fi

    echo "Buscando paquete '$PKG_NAME'..."
    SCRIPT_URL=$(curl -s "$REGISTRY_URL" | jq -r ".packages.\"$PKG_NAME\".url")

    if [ "$SCRIPT_URL" = "null" ] || [ -z "$SCRIPT_URL" ]; then
        echo "Error: El paquete '$PKG_NAME' no existe en el registro."
        exit 1
    fi

    echo "Descargando y ejecutando instalador..."
    bash <(curl -s "$SCRIPT_URL")
else
    echo "Uso: curl -sL URL_DE_ESTE_SCRIPT | bash -s -- install <nombre-paquete>"
fi
