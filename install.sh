#!/bin/bash
set -e

echo "Instalando pkgman..."

# Descargar el CLI principal
curl -sL https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/cli.sh -o /tmp/pkgman

# Dar permisos de ejecución
chmod +x /tmp/pkgman

# Mover a un directorio en el PATH del sistema
if [ -w /usr/local/bin ]; then
    mv /tmp/pkgman /usr/local/bin/pkgman
else
    sudo mv /tmp/pkgman /usr/local/bin/pkgman
fi

echo "¡pkgman instalado con éxito! Prueba ejecutando: pkgman"
