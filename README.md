# WinInstall

**`win install python` — that's it.**

Like `apt install` or `brew install` but for Windows. Wraps `winget` and automatically fixes PATH and environment variables after every install — no more hunting through System Properties.

---

## Setup (one time)

**Double-click `setup.bat`** — that's the only step.

It will:
1. Copy the module to your PowerShell modules folder
2. Unblock all files (removes the Windows "downloaded from internet" flag)
3. Register the `win` command in your PowerShell profile
4. Make `win` available immediately in new terminal windows

Then **open a new PowerShell window** and you're ready.

---

## Usage

```powershell
win install python        # Install Python + add to PATH + set PYTHON_HOME
win install java          # Install OpenJDK 21 + set JAVA_HOME
win install go            # Install Go + set GOROOT, GOPATH
win install node          # Install Node.js + add npm to PATH
win install rust          # Install Rust + set CARGO_HOME
win install dotnet        # Install .NET SDK + set DOTNET_ROOT
win install git           # Install Git + add to PATH
win install docker        # Install Docker Desktop
win install vscode        # Install VS Code + add 'code' to PATH

win list                  # See all available packages by category
win search <query>        # Search winget directly for anything
win update <package>      # Upgrade a package
win update --all          # Upgrade everything
win uninstall <package>   # Uninstall a package
win fix-path              # Audit PATH, re-apply all ENV vars
win fix-path --remove-dead  # Also remove dead PATH entries
win help                  # Full help
```

---

## What it fixes that plain winget doesn't

| Problem | winget alone | WinInstall |
|---|---|---|
| PATH not updated after install | You do it manually | Auto-added |
| JAVA_HOME / GOROOT / etc not set | Never set | Auto-set |
| `setx` truncates PATH at 1024 chars | Corrupts your PATH | Uses proper Windows API |
| UAC popup appears silently | Confusing | Prompts you in the terminal |
| Another installer running (1618) | Silent failure | Asks to wait and retry |
| Dead PATH entries pile up | Ignored | `fix-path --remove-dead` |

---

## Adding a new package

Just add an entry to any file in `WinInstall/packages/` — or create a new category file:

```json
// WinInstall/packages/my-tools.json
{
  "_category": "My Tools",
  "_description": "My custom packages",

  "mytool": {
    "aliases": ["mt"],
    "winget_id": "Publisher.MyTool",
    "display_name": "My Tool",
    "description": "Does something useful",
    "install_dir_hints": [
      "C:\\Program Files\\MyTool"
    ],
    "path_additions": [
      "{install_dir}\\bin"
    ],
    "env_vars": {
      "MYTOOL_HOME": "{install_dir}"
    },
    "verify_cmd": "mytool --version",
    "post_install_msg": "MyTool is ready!"
  }
}
```

Then run `setup.bat` again (or just re-copy the `packages/` folder) — no code changes needed.

**`{install_dir}`** is resolved automatically from the first matching `install_dir_hints` path.  
**`%ENV_VAR%`** syntax works in all path fields.

---

## Package categories

| File | Contents |
|---|---|
| `packages/languages.json` | Python, Java, Node, Go, Rust, .NET, Ruby, PHP, Julia |
| `packages/build-tools.json` | Git, Maven, Gradle, CMake, Make, GitHub CLI, curl, FFmpeg, 7-Zip |
| `packages/devops.json` | Docker, kubectl, Terraform, Helm, AWS CLI, Azure CLI, Google Cloud SDK |
| `packages/editors.json` | VS Code, PowerShell 7, Windows Terminal, Neovim, Notepad++ |

---

## File structure

```
win-install/
├── setup.bat                    <- Double-click to install
├── Install-WinInstall.ps1       <- Bootstrap script (called by setup.bat)
└── WinInstall/
    ├── WinInstall.psm1          <- Root loader (dot-sources all .ps1 files)
    ├── WinInstall.psd1          <- Module manifest
    ├── Core.ps1                 <- Helpers, logging, colours, package registry
    ├── Registry.ps1             <- Tracks installed packages locally
    ├── PathEnv.ps1              <- PATH and ENV var management
    ├── Winget.ps1               <- winget wrappers + error handling
    ├── Commands.ps1             <- All user-facing commands (install/list/etc)
    └── packages/
        ├── languages.json       <- Python, Java, Node, Go, Rust, .NET...
        ├── build-tools.json     <- Git, Maven, CMake, curl, FFmpeg...
        ├── devops.json          <- Docker, kubectl, Terraform, AWS CLI...
        └── editors.json         <- VS Code, PowerShell 7, Neovim...
```

---

## Requirements

- Windows 10 (1809+) or Windows 11
- PowerShell 5.1+ (built-in) — also works on PowerShell 7
- `winget` — comes with **App Installer** from the Microsoft Store ([get it here](https://aka.ms/getwinget))
