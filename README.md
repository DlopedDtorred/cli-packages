# CLI Package Manager 📦

A lightweight command-line package manager powered by GitHub Repositories and Issues. Discover, share, and install community-driven scripts instantly.

---

## 🚀 Quick Start (For Users)

### 1. Install the CLI tool globally
Run this command once in your terminal to install the `pkgman` command permanently:

```bash
bash <(curl -sL [https://raw.githubusercontent.com/dlopeddtorred/cli-packages/main/install.sh](https://raw.githubusercontent.com/YOUR_USERNAME/cli-packages/main/install.sh))
```
2. Use your command normally

Once installed, you can use the command from anywhere on your system:
```Bash

pkgman install <package-name>
```
## 🛠️ How to Add Your Own Package (For Contributors)

Want to add your tool to our registry? Follow these simple steps:
### Step 1: Create a Manifest File (pkg.json)

In the root of your package's GitHub repository, create a file named pkg.json with the following structure:
```JSON

{
  "name": "my-awesome-tool",
  "version": "1.0.0",
  "description": "A short description of what your tool does",
  "install": "[https://raw.githubusercontent.com/your-username/your-repo/main/install.sh](https://raw.githubusercontent.com/your-username/your-repo/main/install.sh)"
}
```
### Step 2: Submit via Issue

Once your repository is public and contains the pkg.json file, click the button below to submit your package:

Fill out the form with your package name and your repository URL. An automated Pull Request will be generated for review!
