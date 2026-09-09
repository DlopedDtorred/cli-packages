# 📦 pkgman

A lightweight, decentralized CLI package manager powered by GitHub Repositories and GitHub Actions.

## 🚀 Quick Start

### Installation

Install `pkgman` globally on your system using a single command:

```bash
curl -sL [https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/install.sh](https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/install.sh) | bash
```
Prerequisites: curl, jq, git, and the GitHub CLI (gh) (required for publishing and unpublishing packages).

## 🛠️ Usage
### 1. List Available Packages

Browse all packages registered in the central catalog:
```Bash

pkgman list
```
### 2. Install a Package

Download and run the installer for any package in the registry:
```Bash

pkgman install <package_name>
```
### 3. Uninstall a Local Package

Remove a package executable from your local /usr/local/bin:
```Bash

pkgman remove <package_name>
```
### 4. Publish Your Package (upload)

To publish a package, ensure your local project directory has an install.sh file and is linked to a remote GitHub repository.

Run the following inside your project folder:
```Bash

pkgman upload
```
What happens automatically:

    Generates a pkg.json manifest if missing.

    Checks your GitHub username against developers.json for developer verification status.

    Forks and creates an automated Pull Request against the central registry.

### 5. Remove a Package from Central Registry (unpublish)

Unlist a package from the global catalog:
```Bash

pkgman unpublish <package_name>
```
    Note on Permissions: You can only unpublish a package if your active GitHub user matches the package owner attribute or if you are listed as a verified administrator in developers.json.

## 🔒 Security & Verification

pkgman includes built-in verification checks:

    Verified Developers: Users listed in developers.json earn a [✓ Verified] status flag next to their packages.

    Security Prompt: When installing packages from unverified developers, pkgman prompts for manual confirmation before executing any remote code.

## 📄 Manifest Example (pkg.json)

Your package manifest is auto-generated during pkgman upload:
```JSON

{
  "name": "my-tool",
  "version": "1.0.0",
  "description": "A powerful CLI utility",
  "install": "[https://raw.githubusercontent.com/username/my-tool/main/install.sh](https://raw.githubusercontent.com/username/my-tool/main/install.sh)"
}
```
## 📜 License

Distributed under the MIT License. See LICENSE for more details.
