
#!/bin/bash
set -e

REGISTRY_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/packages.json"
DEVELOPERS_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/developers.json"

# Comando: help
show_help() {
    echo "pkgman - Gestor de paquetes para la CLI"
    echo ""
    echo "Uso:"
    echo "  pkgman <comando> [opciones]"
    echo ""
    echo "Comandos:"
    echo "  install <paquete>   Instala un paquete registrado en el catálogo central"
    echo "  remove <paquete>    Desinstala un paquete del sistema local"
    echo "  unpublish <paquete> Elimina un paquete del registro central (Solo el dueño)"
    echo "  list                Muestra todos los paquetes disponibles para instalar"
    echo "  upload              Detecta install.sh, crea pkg.json y publica tu paquete"
    echo "  help, -h, --help    Muestra esta ayuda"
}

# Comando: install
cmd_install() {
    PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "Error: Debes especificar el nombre de un paquete."
        echo "Uso: pkgman install <nombre_paquete>"
        exit 1
    fi

    echo "==> Buscando '$PKG_NAME' en el registro central..."
    REGISTRY_JSON=$(curl -sL "$REGISTRY_URL")

    PKG_DATA=$(echo "$REGISTRY_JSON" | jq -r ".packages[\"$PKG_NAME\"] // empty")

    if [ -z "$PKG_DATA" ]; then
        echo "Error: El paquete '$PKG_NAME' no se encuentra en el registro."
        exit 1
    fi

    INSTALL_URL=$(echo "$PKG_DATA" | jq -r '.url')
    IS_VERIFIED=$(echo "$PKG_DATA" | jq -r '.verified // false')

    if [ "$IS_VERIFIED" = "true" ]; then
        echo "==> [✓ Desarrollador Verificado] Instalando '$PKG_NAME' seguro..."
    else
        echo "==> ⚠️ ATENCIÓN: El paquete '$PKG_NAME' no es de un desarrollador verificado."
        read -p "¿Deseas continuar con la instalación de todas formas? (s/N): " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
            echo "Instalación cancelada."
            exit 0
        fi
    fi

    echo "==> Descargando e instalando desde '$INSTALL_URL'..."
    curl -sL "$INSTALL_URL" | bash
    echo "¡Paquete '$PKG_NAME' instalado correctamente!"
}

# Comando: remove (desinstalación local)
cmd_remove() {
    PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "Error: Debes especificar el nombre del paquete a eliminar de tu sistema."
        echo "Uso: pkgman remove <nombre_paquete>"
        exit 1
    fi

    TARGET_PATH="/usr/local/bin/$PKG_NAME"

    if [ ! -f "$TARGET_PATH" ]; then
        echo "Error: El ejecutable '$PKG_NAME' no se encuentra instalado en '$TARGET_PATH'."
        exit 1
    fi

    echo "==> Eliminando binario local '$TARGET_PATH'..."

    if [ -w "/usr/local/bin" ]; then
        rm -f "$TARGET_PATH"
    else
        sudo rm -f "$TARGET_PATH"
    fi

    echo "¡El paquete '$PKG_NAME' ha sido desinstalado de tu sistema local correctamente!"
}

# Comando: list
cmd_list() {
    echo "==> Obteniendo lista de paquetes disponibles..."
    REGISTRY_JSON=$(curl -sL "$REGISTRY_URL")
    
    echo "$REGISTRY_JSON" | jq -r '.packages | to_entries[] | 
      if .value.verified == true then
        "  - \(.key) [✓ Verificado]: \(.value.description) (v\(.value.version))"
      else
        "  - \(.key): \(.value.description) (v\(.value.version))"
      fi'
}

# Comando: upload
cmd_upload() {
    echo "==> Preparando publicación del paquete..."

    if [ ! -f "install.sh" ]; then
        echo "Error: No se encontró un archivo install.sh en este directorio."
        exit 1
    fi

    if [ ! -f "pkg.json" ]; then
        echo "No se encontró pkg.json. Generando uno nuevo..."
        
        DIR_NAME=$(basename "$PWD")
        read -p "Nombre del paquete [$DIR_NAME]: " PKG_NAME
        PKG_NAME=${PKG_NAME:-$DIR_NAME}
        
        read -p "Versión [1.0.0]: " PKG_VER
        PKG_VER=${PKG_VER:-1.0.0}
        
        read -p "Descripción: " PKG_DESC
        
        REPO_URL=$(git config --get remote.origin.url | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github\.com\//')
        
        if [ -z "$REPO_URL" ]; then
            echo "Error: Este directorio no está vinculado a un repositorio de GitHub remoto."
            exit 1
        fi
        
        RAW_INSTALL_URL="$(echo "$REPO_URL" | sed 's/github\.com/raw\.githubusercontent\.com/')/main/install.sh"

        cat <<EOF > pkg.json
{
  "name": "$PKG_NAME",
  "version": "$PKG_VER",
  "description": "$PKG_DESC",
  "install": "$RAW_INSTALL_URL"
}
EOF
        echo "pkg.json creado correctamente."
        git add pkg.json
        git commit -m "chore: add pkg.json manifest"
        git push origin main
    fi

    echo "==> Registrando en el catálogo central..."
    
    if ! command -v gh &> /dev/null; then
        echo "Error: Necesitas tener instalada la CLI de GitHub ('gh') para hacer upload."
        echo "Instálala y ejecuta 'gh auth login' primero."
        exit 1
    fi

    PKG_NAME=$(jq -r '.name' pkg.json)
    PKG_VER=$(jq -r '.version' pkg.json)
    PKG_DESC=$(jq -r '.description' pkg.json)
    PKG_INSTALL=$(jq -r '.install' pkg.json)

    MY_GH_USER=$(gh api user -q .login | tr -d '[:space:]')

    # Verificación estricta mediante jq boolean
    DEV_JSON=$(curl -sL "$DEVELOPERS_URL")
    IS_DEV_VERIFIED=$(echo "$DEV_JSON" | jq -r --arg user "$MY_GH_USER" '(.verified // []) | contains([$user])')

    if [ "$IS_DEV_VERIFIED" = "true" ]; then
        echo "==> Usuario '$MY_GH_USER' verificado según developers.json ✓"
        VERIFIED_FLAG=true
    else
        echo "==> Usuario '$MY_GH_USER' no figura en la lista de desarrolladores verificados."
        VERIFIED_FLAG=false
    fi

    gh repo fork dlopeddtorred/cli-packages --clone=false 2>/dev/null || true
    
    TMP_DIR=$(mktemp -d)
    git clone "https://github.com/$MY_GH_USER/cli-packages.git" "$TMP_DIR"
    
    cd "$TMP_DIR"
    git remote add upstream https://github.com/dlopeddtorred/cli-packages.git 2>/dev/null || true
    git fetch upstream
    git checkout main
    git merge upstream/main

    BRANCH_NAME="add-$PKG_NAME"
    git checkout -b "$BRANCH_NAME"

    # Inyección de metadatos completa incluyendo owner
    jq --arg name "$PKG_NAME" \
       --arg ver "$PKG_VER" \
       --arg desc "$PKG_DESC" \
       --arg url "$PKG_INSTALL" \
       --arg owner "$MY_GH_USER" \
       --argjson is_ver "$VERIFIED_FLAG" \
       '.packages[$name] = {"name": $name, "version": $ver, "description": $desc, "url": $url, "owner": $owner, "verified": $is_ver}' \
       packages.json > packages.tmp.json && mv packages.tmp.json packages.json

    git add packages.json
    git commit -m "chore: add $PKG_NAME"
    git push origin "$BRANCH_NAME" --force

    gh pr create \
      --repo dlopeddtorred/cli-packages \
      --title "Add package: $PKG_NAME" \
      --body "Automated submission via pkgman upload by @$MY_GH_USER" \
      --head "$MY_GH_USER:$BRANCH_NAME" \
      --base main

    echo "¡Paquete $PKG_NAME enviado con éxito!"
    rm -rf "$TMP_DIR"
}

# Comando: unpublish (borrado central condicional)
cmd_unpublish() {
    PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "Error: Debes especificar el paquete a eliminar del registro central."
        echo "Uso: pkgman unpublish <nombre_paquete>"
        exit 1
    fi

    if ! command -v gh &> /dev/null; then
        echo "Error: Necesitas la CLI de GitHub ('gh') instalada y autenticada."
        exit 1
    fi

    MY_GH_USER=$(gh api user -q .login | tr -d '[:space:]')
    REGISTRY_JSON=$(curl -sL "$REGISTRY_URL")

    PKG_DATA=$(echo "$REGISTRY_JSON" | jq -r ".packages[\"$PKG_NAME\"] // empty")

    if [ -z "$PKG_DATA" ]; then
        echo "Error: El paquete '$PKG_NAME' no existe en el registro central."
        exit 1
    fi

    PKG_OWNER=$(echo "$PKG_DATA" | jq -r '.owner // empty' | tr -d '[:space:]')

    # Comprobar lista de desarrolladores
    DEV_JSON=$(curl -sL "$DEVELOPERS_URL")
    IS_DEV_VERIFIED=$(echo "$DEV_JSON" | jq -r --arg user "$MY_GH_USER" '(.verified // []) | contains([$user])')

    # Evaluación estricta de permisos
    if [ "$MY_GH_USER" != "$PKG_OWNER" ] && [ "$IS_DEV_VERIFIED" != "true" ]; then
        echo "❌ Permiso denegado: El paquete '$PKG_NAME' pertenece a @$PKG_OWNER."
        echo "Tu usuario actual es @$MY_GH_USER."
        echo "Solo el propietario original o un administrador verificado puede eliminarlo."
        exit 1
    fi

    echo "==> Permisos confirmados para @$MY_GH_USER. Generando solicitud de eliminación..."

    gh repo fork dlopeddtorred/cli-packages --clone=false 2>/dev/null || true
    TMP_DIR=$(mktemp -d)
    git clone "https://github.com/$MY_GH_USER/cli-packages.git" "$TMP_DIR"

    cd "$TMP_DIR"
    git remote add upstream https://github.com/dlopeddtorred/cli-packages.git 2>/dev/null || true
    git fetch upstream
    git checkout main
    git merge upstream/main

    BRANCH_NAME="remove-$PKG_NAME"
    git checkout -b "$BRANCH_NAME"

    # Eliminación del nodo en packages.json
    jq --arg name "$PKG_NAME" 'del(.packages[$name])' packages.json > packages.tmp.json && mv packages.tmp.json packages.json

    git add packages.json
    git commit -m "chore: remove package $PKG_NAME"
    git push origin "$BRANCH_NAME" --force

    gh pr create \
      --repo dlopeddtorred/cli-packages \
      --title "Remove package: $PKG_NAME" \
      --body "Removal request for **$PKG_NAME** authorized by owner @$MY_GH_USER" \
      --head "$MY_GH_USER:$BRANCH_NAME" \
      --base main

    echo "¡Solicitud de eliminación enviada con éxito para '$PKG_NAME'!"
    rm -rf "$TMP_DIR"
}

# Evaluador principal
case "$1" in
    install)
        cmd_install "$2"
        ;;
    remove|uninstall)
        cmd_remove "$2"
        ;;
    unpublish)
        cmd_unpublish "$2"
        ;;
    list)
        cmd_list
        ;;
    upload)
        cmd_upload
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo "Comando no reconocido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
