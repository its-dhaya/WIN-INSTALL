# WinInstall

> `win install python` -- that's it.

Like `apt install` or `brew install`, but for Windows.  
Wraps `winget` and automatically fixes PATH and environment variables after every install -- no more hunting through System Properties.

---

## Install (one line)

Open **any PowerShell window** and paste:

```powershell
irm https://raw.githubusercontent.com/its-dhaya/WIN-INSTALL/main/get.ps1 | iex
```

That's it. No cloning. No downloading. No setup steps.  
The `win` command will be available in every new PowerShell window after that.

---

## Usage

```powershell
win install python
win install java
win install go
win install node
win install rust
win install dotnet
win install git
win install docker
win install vscode
```

```powershell
win list                    # browse all packages by category
win search <query>          # search winget directly for anything
win update <package>        # upgrade a package
win update --all            # upgrade everything at once
win uninstall <package>     # uninstall a package
win fix-path                # audit PATH and re-apply all ENV vars
win fix-path --remove-dead  # also remove broken PATH entries
win help                    # full command reference
```

---

## What it fixes that plain winget doesn't

| Problem                                  | winget alone           | WinInstall                  |
| ---------------------------------------- | ---------------------- | --------------------------- |
| PATH not updated after install           | You do it manually     | Auto-added                  |
| JAVA_HOME / GOROOT / CARGO_HOME not set  | Never set              | Auto-set                    |
| setx truncates PATH at 1024 chars        | Silently corrupts PATH | Uses proper Windows API     |
| UAC popup appears with no context        | Confusing              | Prompts you in the terminal |
| Another installer already running (1618) | Silent failure         | Asks to wait and retry      |
| Dead PATH entries pile up over time      | Ignored                | win fix-path --remove-dead  |

---

## Supported packages

### Languages

| Command              | Installs          | Sets                              |
| -------------------- | ----------------- | --------------------------------- |
| `win install python` | Python 3.12       | PYTHON_HOME, adds Scripts to PATH |
| `win install java`   | OpenJDK 21 LTS    | JAVA_HOME, JDK_HOME               |
| `win install java17` | OpenJDK 17 LTS    | JAVA_HOME, JDK_HOME               |
| `win install node`   | Node.js LTS       | NODE_HOME, adds npm to PATH       |
| `win install go`     | Go                | GOROOT, GOPATH                    |
| `win install rust`   | Rust (rustup)     | CARGO_HOME, RUSTUP_HOME           |
| `win install dotnet` | .NET SDK 8 LTS    | DOTNET_ROOT                       |
| `win install ruby`   | Ruby 3.2 + DevKit | RUBY_HOME                         |
| `win install php`    | PHP 8.3           | PHP_HOME                          |
| `win install julia`  | Julia             | JULIA_HOME                        |

### Build Tools

| Command              | Installs                                |
| -------------------- | --------------------------------------- |
| `win install git`    | Git                                     |
| `win install maven`  | Apache Maven (sets MAVEN_HOME, M2_HOME) |
| `win install gradle` | Gradle (sets GRADLE_HOME)               |
| `win install cmake`  | CMake                                   |
| `win install make`   | GNU Make                                |
| `win install gh`     | GitHub CLI                              |
| `win install curl`   | curl                                    |
| `win install ffmpeg` | FFmpeg                                  |
| `win install 7zip`   | 7-Zip                                   |

### DevOps & Cloud

| Command                 | Installs         |
| ----------------------- | ---------------- |
| `win install docker`    | Docker Desktop   |
| `win install kubectl`   | kubectl          |
| `win install terraform` | Terraform        |
| `win install helm`      | Helm             |
| `win install awscli`    | AWS CLI          |
| `win install azurecli`  | Azure CLI        |
| `win install gcloud`    | Google Cloud SDK |

### Editors & Shells

| Command                       | Installs                    |
| ----------------------------- | --------------------------- |
| `win install vscode`          | VS Code (adds code to PATH) |
| `win install powershell`      | PowerShell 7                |
| `win install windowsterminal` | Windows Terminal            |
| `win install neovim`          | Neovim                      |
| `win install notepadplusplus` | Notepad++                   |

Most packages support aliases too -- `win install py`, `win install jdk`, `win install k8s` all work.

---

## Adding a new package

No code changes needed. Add an entry to any file in `WinInstall/packages/` -- or create a new category file:

```json
{
  "_category": "My Tools",
  "_description": "My custom packages",

  "mytool": {
    "aliases": ["mt"],
    "winget_id": "Publisher.MyTool",
    "display_name": "My Tool",
    "description": "Does something useful",
    "install_dir_hints": ["C:\\Program Files\\MyTool"],
    "path_additions": ["{install_dir}\\bin"],
    "env_vars": {
      "MYTOOL_HOME": "{install_dir}"
    },
    "verify_cmd": "mytool --version",
    "post_install_msg": "MyTool is ready!"
  }
}
```

- `{install_dir}` resolves automatically from the first matching `install_dir_hints` path
- `%ENV_VAR%` syntax works in all path fields
- New category files are auto-discovered -- no registration needed

---

## File structure

```
wininstall/
|-- get.ps1                      <- one-line remote installer
|-- setup.bat                    <- local installer (double-click)
|-- Install-WinInstall.ps1       <- bootstrap (called by setup.bat)
|-- README.md
+-- WinInstall/
    |-- WinInstall.psm1          <- root loader
    |-- WinInstall.psd1          <- module manifest
    |-- Core.ps1                 <- helpers, logging, package registry
    |-- Registry.ps1             <- tracks installed packages locally
    |-- PathEnv.ps1              <- PATH and ENV var management
    |-- Winget.ps1               <- winget wrappers + retry logic
    |-- Commands.ps1             <- all user-facing commands
    +-- packages/
        |-- languages.json       <- Python, Java, Node, Go, Rust, .NET...
        |-- build-tools.json     <- Git, Maven, CMake, curl, FFmpeg...
        |-- devops.json          <- Docker, kubectl, Terraform, AWS/Azure/GCP
        +-- editors.json         <- VS Code, PowerShell 7, Neovim...
```

---

## Requirements

- Windows 10 (1809+) or Windows 11
- PowerShell 5.1+ (built-in) -- also works with PowerShell 7
- winget -- comes with App Installer from the Microsoft Store: https://aka.ms/getwinget

---

## Local install (no internet)

If you have the repo locally, double-click `setup.bat`. Same result.

---

## License

MIT
