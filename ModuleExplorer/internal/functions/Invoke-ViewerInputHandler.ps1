<#
.SYNOPSIS
    Routes a console key press to the correct handler for the viewer's current state.

.DESCRIPTION
    Invoke-ViewerInputHandler is the central input dispatcher for Show-ModuleCommandViewer.
    It examines $State.View to determine the active view and dispatches the key press to
    the appropriate per-view logic. All state changes are made directly on the $State
    hashtable (a reference type), so callers see mutations immediately after the call.

    Returns $null to signal the viewer should exit; returns $true to continue the loop.

.PARAMETER KeyInfo
    The ConsoleKeyInfo captured by [Console]::ReadKey().

.PARAMETER State
    Mutable viewer state hashtable. Expected keys: View, CommandIndex,
    CommandListScrollOffset, CommandListPageSize, FilteredCommands, SearchString,
    HelpOptionIndex, HelpOptions, ParameterIndex, ParameterListScrollOffset,
    ParameterListPageSize, Parameters, CurrentCommand, CurrentParameter,
    HelpContentLines, HelpContentScrollOffset, HelpContentPageSize, LiveContext.

.OUTPUTS
    $null  — caller should exit the viewer loop.
    $true  — caller should continue the viewer loop.
#>
function Invoke-ViewerInputHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.ConsoleKeyInfo]$KeyInfo,

        [Parameter(Mandatory)]
        [hashtable]$State
    )

    # Type-to-search: alphanumeric, hyphen, underscore — Description view only
    if ($State.View -eq 'Description' -and
        (($KeyInfo.KeyChar -ge 'a' -and $KeyInfo.KeyChar -le 'z') -or
         ($KeyInfo.KeyChar -ge 'A' -and $KeyInfo.KeyChar -le 'Z') -or
         ($KeyInfo.KeyChar -ge '0' -and $KeyInfo.KeyChar -le '9') -or
         $KeyInfo.KeyChar -eq '-' -or $KeyInfo.KeyChar -eq '_')) {
        $State.SearchString += $KeyInfo.KeyChar
        $State.CommandIndex = 0
        $State.CommandListScrollOffset = 0
        return $true
    }

    switch ($State.View) {

        'Description' {
            switch ($KeyInfo.Key) {
                ([System.ConsoleKey]::UpArrow) {
                    if ($State.CommandIndex -gt 0) {
                        $State.CommandIndex--
                        if ($State.CommandIndex -lt $State.CommandListScrollOffset) {
                            $State.CommandListScrollOffset = $State.CommandIndex
                        }
                    }
                }
                ([System.ConsoleKey]::DownArrow) {
                    $total = $State.FilteredCommands.Count
                    if ($total -gt 0 -and $State.CommandIndex -lt ($total - 1)) {
                        $State.CommandIndex++
                        # -2 accounts for both scroll indicator rows
                        if ($State.CommandIndex -ge ($State.CommandListScrollOffset + $State.CommandListPageSize - 2)) {
                            $State.CommandListScrollOffset++
                        }
                    }
                }
                ([System.ConsoleKey]::RightArrow) {
                    if ($State.CommandIndex -ge 0 -and $State.CommandIndex -lt $State.FilteredCommands.Count) {
                        $State.CurrentCommand = $State.FilteredCommands[$State.CommandIndex]
                        $State.View = 'HelpOptions'
                        $State.HelpOptionIndex = 0
                        $State.SearchString = ''
                    }
                }
                ([System.ConsoleKey]::Enter) {
                    if ($State.CommandIndex -ge 0 -and $State.CommandIndex -lt $State.FilteredCommands.Count) {
                        $State.CurrentCommand = $State.FilteredCommands[$State.CommandIndex]
                        $State.View = 'HelpOptions'
                        $State.HelpOptionIndex = 0
                        $State.SearchString = ''
                    }
                }
                ([System.ConsoleKey]::LeftArrow) {
                    if ($State.SearchString.Length -gt 0) {
                        $State.SearchString = $State.SearchString.Substring(0, $State.SearchString.Length - 1)
                        $State.CommandIndex = 0
                        $State.CommandListScrollOffset = 0
                    } else {
                        return $null
                    }
                }
                ([System.ConsoleKey]::Backspace) {
                    if ($State.SearchString.Length -gt 0) {
                        $State.SearchString = $State.SearchString.Substring(0, $State.SearchString.Length - 1)
                        $State.CommandIndex = 0
                        $State.CommandListScrollOffset = 0
                    }
                }
            }
        }

        'HelpOptions' {
            switch ($KeyInfo.Key) {
                ([System.ConsoleKey]::UpArrow) {
                    if ($State.HelpOptionIndex -gt 0) { $State.HelpOptionIndex-- }
                }
                ([System.ConsoleKey]::DownArrow) {
                    if ($State.HelpOptionIndex -lt ($State.HelpOptions.Count - 1)) { $State.HelpOptionIndex++ }
                }
                ([System.ConsoleKey]::RightArrow) { Invoke-ViewerHelpOptionSelect -State $State }
                ([System.ConsoleKey]::Enter)       { Invoke-ViewerHelpOptionSelect -State $State }
                ([System.ConsoleKey]::LeftArrow) {
                    $State.View = 'Description'
                    $State.CurrentCommand = $null
                    $State.HelpContentLines = @()
                    $State.HelpContentScrollOffset = 0
                }
            }
        }

        'ParameterList' {
            switch ($KeyInfo.Key) {
                ([System.ConsoleKey]::UpArrow) {
                    if ($State.ParameterIndex -gt 0) {
                        $State.ParameterIndex--
                        if ($State.ParameterIndex -lt $State.ParameterListScrollOffset) {
                            $State.ParameterListScrollOffset = $State.ParameterIndex
                        }
                    }
                }
                ([System.ConsoleKey]::DownArrow) {
                    if ($State.Parameters.Count -gt 0 -and $State.ParameterIndex -lt ($State.Parameters.Count - 1)) {
                        $State.ParameterIndex++
                        if ($State.ParameterIndex -ge ($State.ParameterListScrollOffset + $State.ParameterListPageSize)) {
                            $State.ParameterListScrollOffset++
                        }
                    }
                }
                ([System.ConsoleKey]::RightArrow) { Invoke-ViewerParameterSelect -State $State }
                ([System.ConsoleKey]::Enter)       { Invoke-ViewerParameterSelect -State $State }
                ([System.ConsoleKey]::LeftArrow) {
                    $State.View = 'HelpOptions'
                    $State.Parameters = @()
                    $State.CurrentParameter = $null
                }
            }
        }

        { $_ -in 'HelpContent', 'ParameterHelpContent' } {
            switch ($KeyInfo.Key) {
                ([System.ConsoleKey]::LeftArrow) {
                    $State.View = if ($State.View -eq 'ParameterHelpContent') { 'ParameterList' } else { 'HelpOptions' }
                    $State.HelpContentLines = @()
                    $State.HelpContentScrollOffset = 0
                }
                ([System.ConsoleKey]::RightArrow) {
                    if ($State.HelpOptions[$State.HelpOptionIndex] -eq 'Online') {
                        try   { Get-Help $State.CurrentCommand.CommandInfo -Online }
                        catch { $State.HelpContentLines = @('[red]Could not retrieve online help. Press Left to go back.[/]') }
                    }
                }
                ([System.ConsoleKey]::Enter) {
                    if ($State.HelpOptions[$State.HelpOptionIndex] -eq 'Online') {
                        try   { Get-Help $State.CurrentCommand.CommandInfo -Online }
                        catch { $State.HelpContentLines = @('[red]Could not retrieve online help. Press Left to go back.[/]') }
                    }
                }
                ([System.ConsoleKey]::UpArrow) {
                    if ($State.HelpContentScrollOffset -gt 0) { $State.HelpContentScrollOffset-- }
                }
                ([System.ConsoleKey]::DownArrow) {
                    if (($State.HelpContentScrollOffset + $State.HelpContentPageSize) -lt $State.HelpContentLines.Count) {
                        $State.HelpContentScrollOffset++
                    }
                }
            }
        }
    }

    return $true
}

function Invoke-ViewerHelpOptionSelect {
    param([hashtable]$State)
    $selectedHelpType = $State.HelpOptions[$State.HelpOptionIndex]
    $State.HelpContentLines = @('[grey]Fetching help...[/]')
    $State.HelpContentScrollOffset = 0

    if ($selectedHelpType -eq 'Parameters') {
        $State.Parameters = Get-SortedParameterList -Parameters $State.CurrentCommand.CommandInfo.Parameters.Values
        $State.ParameterIndex = 0
        $State.ParameterListScrollOffset = 0
        $State.View = 'ParameterList'
    } else {
        $State.View = 'HelpContent'
        $State.LiveContext.Refresh()
        $State.HelpContentLines = Get-CommandHelpContent -HelpType $selectedHelpType -CommandInfo $State.CurrentCommand.CommandInfo
    }
}

function Invoke-ViewerParameterSelect {
    param([hashtable]$State)
    if ($State.Parameters.Count -gt 0 -and
        $State.ParameterIndex -ge 0 -and
        $State.ParameterIndex -lt $State.Parameters.Count) {

        $State.CurrentParameter = $State.Parameters[$State.ParameterIndex]
        $State.HelpContentLines = @('[grey]Fetching parameter help...[/]')
        $State.HelpContentScrollOffset = 0
        $State.View = 'ParameterHelpContent'
        $State.LiveContext.Refresh()
        $State.HelpContentLines = Get-ParameterHelpContent `
            -CommandName         $State.CurrentCommand.Name `
            -ParameterName       $State.CurrentParameter.Name `
            -FallbackHelpMessage $State.CurrentParameter.HelpMessage
    }
}
