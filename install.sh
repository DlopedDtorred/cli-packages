#!/bin/bash
set -e

echo "Instalando pkgman..."

# Descargar la última versión del script CLI
curl -sL https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/cli.sh -o /tmp/pkgman

# Dar permisos de ejecución
chmod +x /tmp/pkgman

# Mover el ejecutable al PATH del sistema
if [ -w /usr/local/bin ]; then
    mv /tmp/pkgman /usr/local/bin/pkgman
else
    sudo mv /tmp/pkgman /usr/local/bin/pkgman
fi

echo "✨ ¡Instalación exitosa! Ya puedes usar 'pkgman'."
echo "Prueba ejecutando: pkgman help"
