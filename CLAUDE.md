# ModuleExplorer — Claude Context

## Project Overview

**ModuleExplorer** is a PowerShell TUI module for browsing installed PowerShell modules and their commands interactively.

- **Repo**: https://github.com/DearingDev/ModuleExplorer
- **Language**: PowerShell 100%
- **Entry point**: `Show-ModuleExplorer` → calls `Show-ModuleCommandViewer`
- **Key features**: module list with filtering, command viewer, detailed help display

### Project Structure

```
ModuleExplorer/
├── functions/
│   ├── Show-ModuleExplorer.ps1        # Public: module picker TUI (entry point)
│   └── Show-ModuleCommandViewer.ps1   # Public: command/help TUI (orchestrator)
└── internal/
    ├── functions/
    │   ├── Get-ScrollableListView.ps1      # Reusable scrollable list renderer
    │   ├── Get-CommandHelpContent.ps1      # Help fetcher (Examples/Detailed/Full/Online)
    │   ├── Get-ParameterHelpContent.ps1    # Per-parameter help fetcher
    │   ├── Get-SortedParameterList.ps1     # Sorts params: non-common first, then common
    │   ├── Invoke-ViewerInputHandler.ps1   # State-machine input dispatcher
    │   ├── Update-ViewerLayout.ps1         # Live layout renderer
    │   └── New-ModuleDataProvider.ps1      # Data provider for PS module data
    └── scripts/
        └── UIConfig.ps1                    # $script:UIConfig — colors, strings, layout
build/                 # Build/publish scripts
tests/
├── general/           # Module-level tests (manifest, PSScriptAnalyzer, help coverage)
└── functions/         # Unit tests for internal helpers
readme.md
```

### Internal Architecture

The command viewer is a five-state machine: `Description → HelpOptions → HelpContent / ParameterList → ParameterHelpContent`. All key-routing is in `Invoke-ViewerInputHandler`; all rendering in `Update-ViewerLayout`. Data is abstracted via a provider hashtable (`New-ModuleDataProvider`) passed through `$State.DataProvider`.

### Install / Run

```powershell
Install-Module -Name ModuleExplorer
Show-ModuleExplorer
```

---

## Dependency: PwshSpectreConsole

All TUI rendering is done via **PwshSpectreConsole**, a PowerShell wrapper around the Spectre.Console .NET library.

- **Repo**: https://github.com/ShaunLawrie/PwshSpectreConsole
- **Docs**: https://pwshspectreconsole.com/
- **Latest stable**: v2.3.0
- **Install**: `Install-Module PwshSpectreConsole -Scope CurrentUser`
- **Local path** (typical): `$env:PSModulePath` — usually `~\Documents\PowerShell\Modules\PwshSpectreConsole`

### Key Commands by Category

#### Prompts (user input)
| Command | Purpose |
|---|---|
| `Read-SpectreSelection` | Single-item selection list |
| `Read-SpectreMultiSelection` | Multi-item selection list |
| `Read-SpectreSelectionGrouped` | Grouped single selection |
| `Read-SpectreMultiSelectionGrouped` | Grouped multi selection |
| `Read-SpectreText` | Free text input |
| `Read-SpectreConfirm` | Yes/No confirmation |
| `Read-SpectrePause` | Press any key to continue |

#### Formatting / Layout
| Command | Purpose |
|---|---|
| `Format-SpectrePanel` | Bordered panel/box around content |
| `Format-SpectreTable` | Rich table rendering |
| `Format-SpectreColumns` | Multi-column layout |
| `Format-SpectreRows` | Stack renderables vertically |
| `Format-SpectreGrid` | Grid layout |
| `Format-SpectreAligned` | Alignment wrapper |
| `Format-SpectreTree` | Tree/hierarchy display |
| `Format-SpectreBarChart` | Horizontal bar chart |
| `Format-SpectreBreakdownChart` | Breakdown/pie-style chart |
| `Format-SpectreJson` | Syntax-highlighted JSON |
| `Format-SpectreException` | Pretty exception display |
| `Format-SpectreTextPath` | Styled file path display |
| `Format-SpectrePadded` | Padding wrapper |
| `New-SpectreLayout` | Named layout regions |
| `New-SpectreGridRow` | Row for grid layout |
| `New-SpectreChartItem` | Item for chart commands |
| `Add-SpectreTableRow` | Add row to a table object |

#### Writing / Output
| Command | Purpose |
|---|---|
| `Write-SpectreHost` | Markup-aware output (like `Write-Host`) |
| `Out-SpectreHost` | Pipe objects to Spectre output |
| `Write-SpectreRule` | Horizontal divider rule with label |
| `Write-SpectreFigletText` | Large ASCII/Figlet text |
| `Write-SpectreCalendar` | Calendar widget |
| `Get-SpectreEscapedText` | Escape markup characters in strings |

#### Live / Async
| Command | Purpose |
|---|---|
| `Invoke-SpectreCommandWithStatus` | Spinner/status while running a scriptblock |
| `Invoke-SpectreCommandWithProgress` | Progress bar while running tasks |
| `Invoke-SpectreLive` | Live-updating renderable (e.g. live table) |
| `Add-SpectreJob` | Add a job for progress tracking |
| `Wait-SpectreJobs` | Wait for all tracked jobs to complete |
| `Invoke-SpectreScriptBlockQuietly` | Run scriptblock suppressing output |

#### Config
| Command | Purpose |
|---|---|
| `Set-SpectreColors` | Set default accent/highlight colors |
| `Get-SpectreColors` | Get current color config |
| `Start-SpectreRecording` / `Stop-SpectreRecording` | Record terminal output to file |

#### Demo / Help
| Command | Purpose |
|---|---|
| `Start-SpectreDemo` | Full interactive feature demo |
| `Get-SpectreDemoFeatures` | Show Spectre.Console feature list |
| `Get-SpectreDemoColors` | Show available colors |
| `Get-SpectreDemoEmoji` | Show available emoji names |
| `Open-PwshSpectreConsoleHelp` | Open docs in browser |

### Markup Syntax

PwshSpectreConsole uses Spectre.Console markup in strings passed to `Write-SpectreHost` and similar commands:

```powershell
Write-SpectreHost "[bold red]Error:[/] Something went wrong"
Write-SpectreHost "[green]Success![/]"
Write-SpectreHost "[:warning:] Watch out"   # emoji by name
```

Colors can be named (`red`, `blue`, `green`) or hex (`#ff5733`). Use `Get-SpectreEscapedText` to safely escape user-supplied strings before embedding in markup.

### Common Patterns in This Project

```powershell
# Selection list
$selected = Read-SpectreSelection -Choices $moduleNames -Title "Select a module"

# Display in a panel
$content | Format-SpectrePanel -Title "Help" -Expand

# Status spinner during slow operations
Invoke-SpectreCommandWithStatus -Title "Loading..." -ScriptBlock {
    # slow work here
}

# Table display
$table = Format-SpectreTable -Data $commands -Property Name, CommandType, Synopsis
```

---

## Development Notes

- Run tests with Pester: `Invoke-Pester ./tests/`
- The module manifest is in `ModuleExplorer/ModuleExplorer.psd1`
- PwshSpectreConsole full docs: https://pwshspectreconsole.com/reference/demo/get-spectredemofeatures/
