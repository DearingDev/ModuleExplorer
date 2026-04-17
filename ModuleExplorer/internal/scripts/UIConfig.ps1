<#
.SYNOPSIS
    Centralizes all hardcoded UI configuration values for the ModuleExplorer module.

.DESCRIPTION
    This script is dot-sourced at module import time and populates the module-scoped
    $script:UIConfig hashtable. All colors, layout constants, display strings, and
    static lists that were previously scattered throughout Show-ModuleCommandViewer
    and Show-ModuleExplorer are consolidated here.

    Modify this file to retheme or reconfigure the module's TUI appearance without
    touching any function logic.
#>

$script:UIConfig = @{

    # -- Color / theme tokens --------------------------------------------------
    # Values are Spectre Console markup color names (or "bold"/"italic" modifiers).
    Colors = @{
        Cmdlet      = 'green'
        Function    = 'blue'
        Alias       = 'magenta'
        Highlight   = 'yellow bold'   # Selected item cursor
        Muted       = 'grey'          # Scroll indicators, empty-state text
        Error       = 'bold red'
        Success     = 'italic green'
        Title       = 'green bold'    # Module/command viewer title
        Exit        = 'mediumpurple3_1'
        Refresh     = 'steelblue1_1'
    }

    # -- Layout constants ------------------------------------------------------
    Layout = @{
        CommandPaneRatio  = 1   # Left pane relative width (vs. RightPaneRatio)
        RightPaneRatio    = 3   # Right pane relative width
        FixedRowsOverhead = 4   # Rows consumed by title, instructions, borders
        MinPageSize       = 1   # Minimum scrollable page height (rows)
        MinNameLength     = 10  # Minimum truncated command name width (chars)
        PanelBorder       = 'Rounded'
        DefaultPageSize   = 15
    }

    # -- Display strings -------------------------------------------------------
    # Centralizes all user-visible text so they can be changed in one place.
    Strings = @{
        ExitChoice         = '<-- Exit'
        RefreshChoice      = 'Refresh List'
        ShowGrouped        = 'Show Grouped Modules'
        HideGrouped        = 'Hide Grouped Modules'
        NoModulesFound     = 'No PowerShell modules found.'
        SelectPrompt       = 'Select a PowerShell Module to Explore (or Exit):'
        LoadingModules     = 'Loading PowerShell Modules...'
        LoadingCommands    = 'Loading command list...'
        SelectCommand      = 'Select a command to see description.'
    }

    # -- Static option lists ---------------------------------------------------
    HelpOptions = @('Examples', 'Detailed', 'Full', 'Online', 'Parameters')

    # Full list of PowerShell common parameters (used to sort/style param lists)
    CommonParameters = @(
        'Verbose', 'Debug', 'ErrorAction', 'ErrorVariable', 'WarningAction',
        'WarningVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable',
        'InformationAction', 'InformationVariable', 'ProgressAction'
    )
}
