<#
.SYNOPSIS
    Renders the current viewer state into the live Spectre Console layout.

.DESCRIPTION
    Update-ViewerLayout centralizes all rendering logic for Show-ModuleCommandViewer.
    On every call it:
      1. Re-applies the search filter to produce State.FilteredCommands.
      2. Clamps navigation indices so they stay within bounds.
      3. Recalculates MaxNameLength from the current console width.
      4. Rebuilds the command-list panel (left pane).
      5. Rebuilds the right pane for whichever view is active:
         Description | HelpOptions | ParameterList | HelpContent | ParameterHelpContent.

    Both pane updates are written directly into the $Layout object; the caller is
    responsible for calling $LiveContext.Refresh() afterwards.

.PARAMETER State
    The mutable viewer state hashtable produced by Show-ModuleCommandViewer.

.PARAMETER Layout
    The root Spectre Console layout object. Must have named children
    'commandListPane' and 'rightPane'.

.EXAMPLE
    Update-ViewerLayout -State $state -Layout $layout
    $state.LiveContext.Refresh()

    Calculates the new layout based on the current state (filtering, selection, scroll)
    and updates the Spectre Console layout object.
#>
function Update-ViewerLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        $Layout
    )

    $cfg = $script:UIConfig

    # --- Filtering -----------------------------------------------------------
    if ($State.SearchString -ne '') {
        $State.FilteredCommands = @($State.AllCommands | Where-Object { $_.Name -like "*$($State.SearchString)*" })
    } else {
        $State.FilteredCommands = $State.AllCommands
    }
    $total = $State.FilteredCommands.Count

    if ($total -eq 0) {
        $State.CommandIndex = -1
        $State.CommandListScrollOffset = 0
    } elseif ($State.CommandIndex -lt 0 -or $State.CommandIndex -ge $total) {
        $State.CommandIndex = 0
        $State.CommandListScrollOffset = 0
    }

    # --- MaxNameLength -------------------------------------------------------
    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $totalRatio   = $cfg.Layout.CommandPaneRatio + $cfg.Layout.RightPaneRatio
    $paneWidth    = if ($totalRatio -gt 0) {
        [Math]::Floor($consoleWidth * ($cfg.Layout.CommandPaneRatio / $totalRatio))
    } else { [Math]::Floor($consoleWidth / 4) }
    $maxNameLen = $paneWidth - 4 - 2  # 4 for panel borders, 2 for selector prefix
    if ($maxNameLen -lt $cfg.Layout.MinNameLength) { $maxNameLen = $cfg.Layout.MinNameLength }
    $State.MaxNameLength = $maxNameLen

    # --- Command List Panel --------------------------------------------------
    $listHeader = "[bold]($total total)[/]"
    if ($State.SearchString -ne '') {
        $listHeader += " Filter: [yellow]'$($State.SearchString | Get-SpectreEscapedText)'[/]"
    }

    if ($total -gt 0 -and $State.CommandIndex -ge 0) {
        $formattedCmds = @($State.FilteredCommands | ForEach-Object {
            $n = $_.Name
            if ($n.Length -gt $State.MaxNameLength) {
                $n = $n.Substring(0, [Math]::Max(0, $State.MaxNameLength - 3)) + '...'
            }
            switch ($_.Type) {
                'Cmdlet'   { "[$($cfg.Colors.Cmdlet)]$n[/]" }
                'Function' { "[$($cfg.Colors.Function)]$n[/]" }
                'Alias'    { "[$($cfg.Colors.Alias)]$n[/]" }
                default    { $n }
            }
        })

        $cmdLines = Get-ScrollableListView `
            -Items         $formattedCmds `
            -SelectedIndex $State.CommandIndex `
            -ScrollOffset  $State.CommandListScrollOffset `
            -PageSize      $State.CommandListPageSize
    } else {
        $cmdLines = @('[grey] (No commands to display) [/]')
    }

    $cmdPanel = $cmdLines | Format-SpectreRows | Format-SpectrePanel -Header $listHeader -Expand -Border Rounded
    $Layout['commandListPane'].Update($cmdPanel) | Out-Null

    # --- Right Pane ----------------------------------------------------------
    $rightRenderable = $null

    switch ($State.View) {

        'Description' {
            $rightHeader = '[bold]Description[/]'
            if ($State.CommandIndex -ge 0 -and $State.CommandIndex -lt $State.FilteredCommands.Count) {
                $cmd = $State.FilteredCommands[$State.CommandIndex]
                $rightHeader = "[bold]Description for $($cmd.Name)[/]"
                $descText = if ($cmd.Synopsis -and $cmd.Synopsis -ne '') {
                    $cmd.Synopsis
                } elseif ($cmd.Type -eq 'Alias' -and $cmd.Definition) {
                    "Alias for: $($cmd.Definition)"
                } else {
                    '[grey]No synopsis available.[/]'
                }
                $rightRenderable = ($descText | Get-SpectreEscapedText) |
                    Format-SpectrePanel -Header $rightHeader -Expand -Border Rounded
            } else {
                $rightRenderable = Write-SpectreHost '[grey]No command selected or found.[/]' -PassThru |
                    Format-SpectrePanel -Header $rightHeader -Expand -Border Rounded
            }
        }

        'HelpOptions' {
            $rightHeader  = "[bold]Help Options for $($State.CurrentCommand.Name)[/]"
            $optionLines  = for ($i = 0; $i -lt $State.HelpOptions.Count; $i++) {
                if ($i -eq $State.HelpOptionIndex) { "[$($cfg.Colors.Highlight)]>[/] $($State.HelpOptions[$i])" }
                else                               { "  $($State.HelpOptions[$i])" }
            }
            $rightRenderable = $optionLines |
                Format-SpectreRows | Format-SpectrePanel -Header $rightHeader -Expand -Border Rounded
        }

        'ParameterList' {
            $rightHeader = "[bold]Parameters for $($State.CurrentCommand.Name)[/]"
            if ($State.Parameters.Count -gt 0) {
                $formattedParams = @($State.Parameters | ForEach-Object {
                    if ($cfg.CommonParameters -contains $_.Name) {
                        "[$($cfg.Colors.Muted)]$($_.Name)[/]"
                    } else {
                        $_.Name
                    }
                })
                $paramLines = Get-ScrollableListView `
                    -Items         $formattedParams `
                    -SelectedIndex $State.ParameterIndex `
                    -ScrollOffset  $State.ParameterListScrollOffset `
                    -PageSize      $State.ParameterListPageSize
            } else {
                $paramLines = @('[grey](No parameters found or command does not support parameters)[/]')
            }
            $rightRenderable = $paramLines |
                Format-SpectreRows | Format-SpectrePanel -Header $rightHeader -Expand -Border Rounded
        }

        { $_ -in 'HelpContent', 'ParameterHelpContent' } {
            $rightHeader = if ($State.View -eq 'ParameterHelpContent') {
                "[bold]Parameter: $($State.CurrentParameter.Name) in $($State.CurrentCommand.Name)[/]"
            } else {
                "[bold]Help: $($State.CurrentCommand.Name) - $($State.HelpOptions[$State.HelpOptionIndex])[/]"
            }
            if ($State.HelpContentLines.Count -gt 0) {
                $helpLines = Get-ScrollableListView `
                    -Items         $State.HelpContentLines `
                    -SelectedIndex -1 `
                    -ScrollOffset  $State.HelpContentScrollOffset `
                    -PageSize      $State.HelpContentPageSize
            } else {
                $helpLines = @('[grey](No help content available for this view)[/]')
            }
            $rightRenderable = $helpLines |
                Format-SpectreRows | Format-SpectrePanel -Header $rightHeader -Expand -Border Rounded
        }
    }

    $Layout['rightPane'].Update($rightRenderable) | Out-Null
}

