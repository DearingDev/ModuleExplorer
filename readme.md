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
`Show-ModuleExplorer` function opens up the TUI launcher to view installed modules.

## Features

* **Interactive Module Exploration**: Users can navigate through a list of all available PowerShell modules on the system.
* **Command Viewing**: Once a module is selected, users can view its commands (cmdlets, functions, and aliases).
* **Filtering**: The list of modules can be filtered by a search string.
* **Detailed Help**: For each command, users can view detailed help information, including synopsis, examples, and full help content.
* **Rich TUI**: Utilizes PwshSpectreConsole for an enhanced interactive experience in the terminal.

## How it Works

The primary function `Show-ModuleExplorer` displays a list of available PowerShell modules. Upon selecting a module, it calls `Show-ModuleCommandViewer` to display the commands within that module. The interface allows for viewing the helps pages of a particular module.

## Credits

- Friedrich Weinmann
  - https://github.com/PowershellFrameworkCollective/PSModuleDevelopment
- Shaun Lawrie
  - https://github.com/ShaunLawrie/PwshSpectreConsole
- Andrew Pla
  - https://github.com/AndrewPla