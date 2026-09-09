#!/bin/bash
set -e

REGISTRY_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/packages.json"
DEVELOPERS_URL="https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/developers.json"

# Command: help
show_help() {
    echo "pkgman - CLI Package Manager"
    echo ""
    echo "Usage:"
    echo "  pkgman <command> [options]"
    echo ""
    echo "Commands:"
    echo "  install <package>   Installs a package registered in the central catalog"
    echo "  remove <package>    Uninstalls a package from the local system"
    echo "  unpublish <package> Removes a package from the central registry (Owner/Dev only)"
    echo "  list                Lists all available packages in the catalog"
    echo "  upload              Detects install.sh, creates pkg.json, and publishes your package"
    echo "  help, -h, --help    Displays this help menu"
}

# Command: install
cmd_install() {
    PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "Error: You must specify a package name."
        echo "Usage: pkgman install <package_name>"
        exit 1
    fi

    echo "==> Searching for '$PKG_NAME' in the central registry..."
    REGISTRY_JSON=$(curl -sL "$REGISTRY_URL")

    PKG_DATA=$(echo "$REGISTRY_JSON" | jq -r ".packages[\"$PKG_NAME\"] // empty")

    if [ -z "$PKG_DATA" ]; then
        echo "Error: Package '$PKG_NAME' was not found in the registry."
        exit 1
    fi

    INSTALL_URL=$(echo "$PKG_DATA" | jq -r '.url')
    IS_VERIFIED=$(echo "$PKG_DATA" | jq -r '.verified // false')

    if [ "$IS_VERIFIED" = "true" ]; then
        echo "==> [✓ Verified Developer] Installing '$PKG_NAME' securely..."
    else
        echo "==> ⚠️ WARNING: Package '$PKG_NAME' is not published by a verified developer."
        read -p "Do you want to proceed with the installation anyway? (y/N): " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
            echo "Installation aborted."
            exit 0
        fi
    fi

    echo "==> Downloading and installing from '$INSTALL_URL'..."
    curl -sL "$INSTALL_URL" | bash
    echo "Package '$PKG_NAME' installed successfully!"
}

# Command: remove (local system cleanup)
cmd_remove() {
    PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "Error: You must specify the package name to remove from your system."
        echo "Usage: pkgman remove <package_name>"
        exit 1
    fi

    TARGET_PATH="/usr/local/bin/$PKG_NAME"

    if [ ! -f "$TARGET_PATH" ]; then
        echo "Error: Executable '$PKG_NAME' was not found in '$TARGET_PATH'."
        exit 1
    fi

    echo "==> Removing local binary '$TARGET_PATH'..."

    if [ -w "/usr/local/bin" ]; then
        rm -f "$TARGET_PATH"
    else
        sudo rm -f "$TARGET_PATH"
    fi

    echo "Package '$PKG_NAME' has been uninstalled from your local system!"
}

# Command: list
cmd_list() {
    echo "==> Fetching list of available packages..."
    REGISTRY_JSON=$(curl -sL "$REGISTRY_URL")
    
    echo "$REGISTRY_JSON" | jq -r '.packages | to_entries[] | 
      if .value.verified == true then
        "  - \(.key) [✓ Verified]: \(.value.description) (v\(.value.version))"
      else
        "  - \(.key): \(.value.description) (v\(.value.version))"
      fi'
}

# Command: upload
cmd_upload() {
    echo "==> Preparing package publication..."

    if [ ! -f "install.sh" ]; then
        echo "Error: No install.sh file found in the current directory."
        exit 1
    fi

    if [ ! -f "pkg.json" ]; then
        echo "No pkg.json found. Generating a new one..."
        
        DIR_NAME=$(basename "$PWD")
        read -p "Package name [$DIR_NAME]: " PKG_NAME
        PKG_NAME=${PKG_NAME:-$DIR_NAME}
        
        read -p "Version [1.0.0]: " PKG_VER
        PKG_VER=${PKG_VER:-1.0.0}
        
        read -p "Description: " PKG_DESC
        
        REPO_URL=$(git config --get remote.origin.url | sed 's/\.git$//' | sed 's/git@github\.com:/https:\/\/github\.com\//')
        
        if [ -z "$REPO_URL" ]; then
            echo "Error: Current directory is not linked to a remote GitHub repository."
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
        echo "pkg.json created successfully."
        git add pkg.json
        git commit -m "chore: add pkg.json manifest"
        git push origin main
    fi

    echo "==> Registering with central catalog..."
    
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI ('gh') is required to perform uploads."
        echo "Please install it and run 'gh auth login' first."
        exit 1
    fi

    PKG_NAME=$(jq -r '.name' pkg.json)
    PKG_VER=$(jq -r '.version' pkg.json)
    PKG_DESC=$(jq -r '.description' pkg.json)
    PKG_INSTALL=$(jq -r '.install' pkg.json)

    MY_GH_USER=$(gh api user -q .login | tr -d '[:space:]')

    # Strict developer verification check
    DEV_JSON=$(curl -sL "$DEVELOPERS_URL")
    IS_DEV_VERIFIED=$(echo "$DEV_JSON" | jq -r --arg user "$MY_GH_USER" '(.verified // []) | contains([$user])')

    if [ "$IS_DEV_VERIFIED" = "true" ]; then
        echo "==> User '$MY_GH_USER' verified via developers.json ✓"
        VERIFIED_FLAG=true
    else
        echo "==> User '$MY_GH_USER' is not listed in verified developers."
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

    # Inject metadata with native boolean flag for verification
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

    echo "Package '$PKG_NAME' submitted successfully!"
    rm -rf "$TMP_DIR"
}

# Command: unpublish (central removal with ownership enforcement)
cmd_unpublish() {
    PKG_NAME="$1"
    if [ -z "$PKG_NAME" ]; then
        echo "Error: You must specify the package name to remove from the central registry."
        echo "Usage: pkgman unpublish <package_name>"
        exit 1
    fi

    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI ('gh') is required and must be authenticated."
        exit 1
    fi

    MY_GH_USER=$(gh api user -q .login | tr -d '[:space:]')
    REGISTRY_JSON=$(curl -sL "$REGISTRY_URL")

    PKG_DATA=$(echo "$REGISTRY_JSON" | jq -r ".packages[\"$PKG_NAME\"] // empty")

    if [ -z "$PKG_DATA" ]; then
        echo "Error: Package '$PKG_NAME' does not exist in the central registry."
        exit 1
    fi

    PKG_OWNER=$(echo "$PKG_DATA" | jq -r '.owner // empty' | tr -d '[:space:]')

    # Check verified developers list
    DEV_JSON=$(curl -sL "$DEVELOPERS_URL")
    IS_DEV_VERIFIED=$(echo "$DEV_JSON" | jq -r --arg user "$MY_GH_USER" '(.verified // []) | contains([$user])')

    # Strict authorization check
    if [ "$MY_GH_USER" != "$PKG_OWNER" ] && [ "$IS_DEV_VERIFIED" != "true" ]; then
        echo "❌ Permission denied: Package '$PKG_NAME' belongs to @$PKG_OWNER."
        echo "Your current GitHub user is @$MY_GH_USER."
        echo "Only the original owner or a verified administrator can unpublish it."
        exit 1
    fi

    echo "==> Authorization confirmed for @$MY_GH_USER. Generating removal pull request..."

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

    # Remove node from packages.json
    jq --arg name "$PKG_NAME" 'del(.packages[$name])' packages.json > packages.tmp.json && mv packages.tmp.json packages.json

    git add packages.json
    git commit -m "chore: remove package $PKG_NAME"
    git push origin "$BRANCH_NAME" --force

    gh pr create \
      --repo dlopeddtorred/cli-packages \
      --title "Remove package: $PKG_NAME" \
      --body "Removal request for **$PKG_NAME** authorized by @$MY_GH_USER" \
      --head "$MY_GH_USER:$BRANCH_NAME" \
      --base main

    echo "Removal request submitted successfully for '$PKG_NAME'!"
    rm -rf "$TMP_DIR"
}

# Main dispatcher
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
        echo "Unrecognized command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
