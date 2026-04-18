<#
.SYNOPSIS
    Displays an interactive viewer for commands (cmdlets, functions, aliases)
    within a selected PowerShell module.

.DESCRIPTION
    Show-ModuleCommandViewer is a private function within the ModuleExplorer module.
    It provides a text-based user interface (TUI) for browsing
    and inspecting commands of a specified PowerShell module.

    The interface is divided into two main panes:

    Left Pane: Lists all exported commands from the selected module. Commands are
    color-coded by type (Cmdlet, Function, Alias). Users can navigate this list
    using arrow keys and filter it by typing.

    Right Pane: Initially displays the synopsis of the selected command. After
    selecting a command (Right Arrow or Enter), it shows help options
    (Examples, Detailed, Full, Online, Parameters). Selecting any help option
    or a specific parameter displays the corresponding help content.

    Navigation is primarily through arrow keys, Enter, and Escape. Instructions
    for key bindings are displayed at the bottom of the viewer.

    This function utilizes the PwshSpectreConsole module to render its UI.

.PARAMETER SelectedModule
    A PSObject representing the PowerShell module whose commands are to be displayed.
    This object MUST have a 'Name' property containing the string name of the module
    (e.g., as returned by Get-Module). This parameter is mandatory. It is provided
    by the caller of this function, the Show-ModuleExplorer function.

.PARAMETER DataProvider
    An optional hashtable providing the data and logic for the viewer. If not supplied,
    a default provider for the selected module is created using New-ModuleDataProvider.
    This allows for dependency injection or alternative data sources.

.INPUTS
    System.Management.Automation.PSObject
    Expects a PSObject with a .Name property that is the name of a module.

.OUTPUTS
    None.
    This function does not return any objects to the pipeline. Its output is entirely
    directed to the host console as an interactive UI. It returns $null upon exiting.

.NOTES
    This is a private function and is not intended to be called directly by users
    of the ModuleExplorer module. It is used internally to provide UI capabilities.

    Requires the PwshSpectreConsole module to be available.
    The function attempts to dynamically adjust the displayed list sizes based on
    console window height. This works best when expanding the window; shrinking
    may not immediately reflect without reselecting the module.

    Search functionality in the command list is case-insensitive and supports
    alphanumeric characters, hyphens, and underscores.

    Key Interactions:
    - Command List (Left Pane - Initial View):
        - Up/Down Arrows: Navigate command list.
        - Type characters: Filter the command list.
        - Backspace/Left Arrow (when search string active): Delete last character from search.
        - Right Arrow / Enter: Select command and move to Help Options view.
        - Left Arrow (no search string): Go back.
        - Escape: Exit the viewer.

    - Help Options (Right Pane - After selecting a command):
        - Up/Down Arrows: Navigate help options.
        - Right Arrow / Enter: View selected help content or parameter list.
        - Left Arrow: Return to Command List (Description view).
        - Escape: Exit the viewer.

    - Parameter List (Right Pane - After selecting "Parameters"):
        - Up/Down Arrows: Navigate parameter list (common parameters are grey).
        - Right Arrow / Enter: View help for selected parameter.
        - Left Arrow: Return to Help Options view.
        - Escape: Exit the viewer.

    - Help Content / Parameter Help Content (Right Pane):
        - Up/Down Arrows: Navigate through help content.
        - Right Arrow / Enter (if "Online" help was selected): Open online help.
        - Left Arrow: Return to Help Options view or Parameter List view.
        - Escape: Exit the viewer.

.EXAMPLE
    # This is a private function. The following shows conceptual internal usage:

    $moduleObject = Get-Module -Name "Pester" -ListAvailable | Select-Object -First 1
    if ($moduleObject) {
        Show-ModuleCommandViewer -SelectedModule $moduleObject
    }
    # This would launch the interactive command viewer for the 'Pester' module.

.LINK
    https://github.com/DearingDev/ModuleExplorer/blob/main/ModuleExplorer/functions/Show-ModuleCommandViewer.ps1
#>
function Show-ModuleCommandViewer {
    param (
        [Parameter(Mandatory)]
        [PSObject]$SelectedModule,

        [hashtable]$DataProvider
    )

    if (-not $DataProvider) {
        $DataProvider = New-ModuleDataProvider -ModuleName $SelectedModule.Name
    }

    $allCommandObjects = @(& $DataProvider.GetItems)

    if (-not $allCommandObjects) {
        Write-SpectreHost "[yellow]No commands found for '$($SelectedModule.Name)'.[/]"
        Read-SpectrePause -Message "[grey]Press Enter to continue...[/]" -NoNewline
        return
    }

    $cfg = $script:UIConfig

    # Build layout
    $initialCmdContent   = Write-SpectreHost "[$($cfg.Colors.Muted)]$($cfg.Strings.LoadingCommands)[/]" -PassThru |
        Format-SpectrePanel -Header '[bold]Commands[/]' -Expand -Border Rounded
    $initialRightContent = Write-SpectreHost "[$($cfg.Colors.Muted)]$($cfg.Strings.SelectCommand)[/]" -PassThru |
        Format-SpectrePanel -Header '[bold]Description[/]' -Expand -Border Rounded

    $commandListPaneLayout = New-SpectreLayout -Name 'commandListPane' -Data $initialCmdContent   -Ratio $cfg.Layout.CommandPaneRatio
    $rightPaneLayout       = New-SpectreLayout -Name 'rightPane'       -Data $initialRightContent -Ratio $cfg.Layout.RightPaneRatio
    $combinedPanel         = New-SpectreLayout -Name 'combinedPanel'   -Columns @($commandListPaneLayout, $rightPaneLayout) -Ratio 20

    $titleText    = "[$($cfg.Colors.Cmdlet) bold]Cmdlets[/], [$($cfg.Colors.Function) bold]Functions[/], and [$($cfg.Colors.Alias) bold]Aliases[/] in $($SelectedModule.Name)"
    $titleRow     = Write-SpectreHost $titleText -PassThru | Format-SpectreAligned -HorizontalAlignment Center
    $instrRow     = Write-SpectreHost '[grey](↑/↓ Navigate | → Select | ← Back | Type to Search | Esc Exit)[/]' -PassThru |
        Format-SpectreAligned -HorizontalAlignment Center
    $layout       = New-SpectreLayout -Name 'root' -Rows @($titleRow, $combinedPanel, $instrRow)

    # Initialize state
    $dynamicPageSize = [Math]::Max($cfg.Layout.MinPageSize, $Host.UI.RawUI.WindowSize.Height - $cfg.Layout.FixedRowsOverhead)
    $state = @{
        AllCommands               = $allCommandObjects
        FilteredCommands          = $allCommandObjects
        View                      = 'Description'
        CommandIndex              = 0
        CommandListScrollOffset   = 0
        CommandListPageSize       = $dynamicPageSize
        SearchString              = ''
        MaxNameLength             = $cfg.Layout.MinNameLength
        HelpOptionIndex           = 0
        HelpOptions               = @(& $DataProvider.GetDetailOptions $null)
        Parameters                = @()
        ParameterIndex            = 0
        ParameterListScrollOffset = 0
        ParameterListPageSize     = $dynamicPageSize
        CurrentCommand            = $null
        CurrentParameter          = $null
        HelpContentLines          = @()
        HelpContentScrollOffset   = 0
        HelpContentPageSize       = $dynamicPageSize
        LiveContext               = $null
        DataProvider              = $DataProvider
    }

    Invoke-SpectreLive -Data $layout -ScriptBlock {
        param([Spectre.Console.LiveDisplayContext]$LiveContext)
        $state.LiveContext = $LiveContext

        try {
            while ($true) {
                # Recalculate page sizes on console resize
                $newPageSize = [Math]::Max(
                    $script:UIConfig.Layout.MinPageSize,
                    $Host.UI.RawUI.WindowSize.Height - $script:UIConfig.Layout.FixedRowsOverhead
                )
                if ($newPageSize -ne $state.CommandListPageSize) {
                    $state.CommandListPageSize   = $newPageSize
                    $state.HelpContentPageSize   = $newPageSize
                    $state.ParameterListPageSize = $newPageSize
                }

                Update-ViewerLayout -State $state -Layout $layout
                $LiveContext.Refresh()

                if (-not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 50; continue }
                $keyInfo = [Console]::ReadKey($true)

                if ($keyInfo.Key -eq [System.ConsoleKey]::Escape) { return $null }

                $result = Invoke-ViewerInputHandler -KeyInfo $keyInfo -State $state
                if ($null -eq $result) { return $null }
            }
        }
        catch {
            Write-SpectreHost "[bold red]Error within Invoke-SpectreLive: $($_.Exception.ToString() | Get-SpectreEscapedText)[/]"
            Read-SpectrePause -Message '[grey]Press Enter to acknowledge error and return...[/]' -NoNewline
            return $null
        }
    }

    Clear-Host
}

