# ModuleExplorer

ModuleExplorer is a PowerShell module that provides an interactive, terminal-based user interface (TUI) to browse and explore PowerShell modules and their commands and parameters.

## Installation

```powershell
Install-Module -Name ModuleExplorer
```

## Quick Start

```powershell
Show-ModuleExplorer
```

`Show-ModuleExplorer` opens an interactive TUI to browse all installed modules, explore their commands, and read help documentation without leaving the terminal.

## Features

* **Interactive Module Exploration**: Navigate a list of all installed PowerShell modules with live filtering.
* **Command Viewer**: Select a module to browse its cmdlets, functions, and aliases with color-coded types.
* **Detailed Help**: View Examples, Detailed, Full, and Online help for any command directly in the TUI.
* **Parameter Browser**: Drill into a command's parameters and read per-parameter help.
* **Rich TUI**: Built on PwshSpectreConsole (Spectre.Console) for a polished terminal experience.

## Navigation

| Key | Action |
|---|---|
| `↑` / `↓` | Move selection |
| `→` / `Enter` | Drill into selected item |
| `←` / `Esc` | Go back (or exit) |
| Type characters | Filter/search the current list |
| `Backspace` | Delete last filter character |

## Architecture

```
ModuleExplorer/
├── functions/
│   ├── Show-ModuleExplorer.ps1        # Module picker — entry point
│   └── Show-ModuleCommandViewer.ps1   # Command/help TUI — orchestrator
└── internal/
    ├── functions/
    │   ├── Get-ScrollableListView.ps1      # Reusable scrollable list renderer
    │   ├── Get-CommandHelpContent.ps1      # Help content fetcher (Examples/Detailed/Full/Online)
    │   ├── Get-ParameterHelpContent.ps1    # Per-parameter help fetcher
    │   ├── Get-SortedParameterList.ps1     # Parameter sorter (non-common first)
    │   ├── Invoke-ViewerInputHandler.ps1   # State-machine input dispatcher
    │   ├── Update-ViewerLayout.ps1         # Live layout renderer
    │   └── New-ModuleDataProvider.ps1      # Data provider for PowerShell modules
    └── scripts/
        └── UIConfig.ps1                    # Centralized colors, strings, and layout constants
```

The viewer is a five-state machine (`Description → HelpOptions → HelpContent / ParameterList → ParameterHelpContent`). All input routing lives in `Invoke-ViewerInputHandler`; all rendering lives in `Update-ViewerLayout`. The data layer is abstracted behind a provider hashtable (`New-ModuleDataProvider`) so the TUI engine can be reused for other data sources.

## Credits

- Friedrich Weinmann — [PSModuleDevelopment](https://github.com/PowershellFrameworkCollective/PSModuleDevelopment) (project template)
- Shaun Lawrie — [PwshSpectreConsole](https://github.com/ShaunLawrie/PwshSpectreConsole)
- Andrew Pla — [AndrewPla](https://github.com/AndrewPla)
