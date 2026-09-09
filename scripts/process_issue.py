import os
import json
import re
import urllib.request
from github import Github

def main():
    # Obtener variables de entorno pasadas por GitHub Actions
    token = os.environ.get("GITHUB_TOKEN")
    issue_number = int(os.environ.get("ISSUE_NUMBER"))
    repo_name = os.environ.get("GITHUB_REPOSITORY")
    
    g = Github(token)
    repo = g.get_repo(repo_name)
    issue = repo.get_issue(number=issue_number)

    # 1. Verificar si tiene la etiqueta 'new-package'
    labels = [label.name for label in issue.labels]
    if "new-package" not in labels:
        print("El issue no tiene la etiqueta 'new-package'. Omitiendo.")
        return

    # 2. Extraer la URL de GitHub del cuerpo del Issue mediante Regex
    body = issue.body or ""
    match = re.search(r"https://github\.com/([a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+)", body)
    
    if not match:
        issue.create_comment("❌ Error: No se encontró una URL válida de repositorio de GitHub en el issue.")
        return

    target_repo = match.group(1).rstrip(".git").rstrip("/")
    manifest_url = f"https://raw.githubusercontent.com/{target_repo}/main/pkg.json"

    # 3. Descargar y parsear el pkg.json
    try:
        req = urllib.request.Request(manifest_url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            manifest = json.loads(response.read().decode('utf-8'))
    except Exception as e:
        issue.create_comment(f"❌ Error: No se pudo descargar o leer `pkg.json` desde `{manifest_url}`. Detalles: `{str(e)}`")
        return

    pkg_name = manifest.get("name")
    pkg_install = manifest.get("install")

    if not pkg_name or not pkg_install:
        issue.create_comment("❌ Error: El archivo `pkg.json` no contiene los campos obligatorios `name` o `install`.")
        return

    # 4. Leer packages.json actual en el repositorio principal
    packages_file = repo.get_contents("packages.json", ref="main")
    packages_data = json.loads(packages_file.decoded_content.decode('utf-8'))

    if "packages" not in packages_data:
        packages_data["packages"] = {}

    # Actualizar contenido
    packages_data["packages"][pkg_name] = {
        "name": pkg_name,
        "version": manifest.get("version", "1.0.0"),
        "description": manifest.get("description", ""),
        "url": pkg_install
    }

    updated_content = json.dumps(packages_data, indent=2) + "\n"

    # 5. Crear una nueva rama, subir el commit y abrir la Pull Request
    branch_name = f"pkg-add-{issue_number}"
    main_ref = repo.get_git_ref("heads/main")

    # Crear la rama desde main
    try:
        repo.create_git_ref(ref=f"refs/heads/{branch_name}", sha=main_ref.object.sha)
    except Exception:
        # Si la rama ya existía, obtenemos su referencia
        pass

    # Crear commit en la nueva rama
    current_file_in_branch = repo.get_contents("packages.json", ref=branch_name)
    repo.update_file(
        path="packages.json",
        message=f"chore: add package {pkg_name} from issue #{issue_number}",
        content=updated_content,
        sha=current_file_in_branch.sha,
        branch=branch_name
    )

    # Crear Pull Request
    pr = repo.create_pull(
        title=f"Add package: {pkg_name} (Issue #{issue_number})",
        body=f"Automated PR to add package **{pkg_name}** requested in issue #{issue_number}.",
        head=branch_name,
        base="main"
    )

    print(f"¡PR creada exitosamente!: {pr.html_url}")

if __name__ == "__main__":
    main()
