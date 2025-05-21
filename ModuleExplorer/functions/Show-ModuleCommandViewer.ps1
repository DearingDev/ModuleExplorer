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
        [PSObject]$SelectedModule
    )

    # Define common PowerShell parameters
    $commonParameterNames = @(
        'Verbose', 'Debug', 'ErrorAction', 'ErrorVariable', 'WarningAction',
        'WarningVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable',
        'InformationAction', 'InformationVariable', 'ProgressAction'
    )

    $commands = Get-Command -Module $SelectedModule.Name | Sort-Object CommandType, Name
    
    if (-not $commands) {
        Write-SpectreHost "[yellow]No exported commands found for module '$($SelectedModule.Name)'.[/]"
        Read-SpectrePause -Message "[grey]Press Enter to continue...[/]" -NoNewline
        return
    }

    # Pre-fetch command details, including synopsis
    $allCommandObjects = @($commands | ForEach-Object {
        $synopsis = ""
        try {
            $helpInfo = Get-Help $_.Name -ErrorAction SilentlyContinue
            if ($helpInfo) {
                if ($helpInfo.Synopsis -is [array]) {
                    $synopsis = ($helpInfo.Synopsis | Select-Object -First 1) -join " "
                } elseif ($helpInfo.Synopsis) {
                    $synopsis = $helpInfo.Synopsis
                }
            }
        } catch {
            Write-Verbose "Failed to get help for command '$($_.Name)': $($_.Exception.Message)"
            # Falls back to empty synopsis string
        }
        
        [PSCustomObject]@{
            Name        = $_.Name
            Type        = $_.CommandType.ToString()
            Source      = $_.Source
            Definition  = $_.Definition
            Synopsis    = $synopsis
            CommandInfo = $_ # Store the OG object
        }
    })

    if (-not $allCommandObjects) {
        Write-SpectreHost "[yellow]Could not retrieve command details for '$($SelectedModule.Name)'.[/]"
        Read-SpectrePause -Message "[grey]Press Enter to continue...[/]" -NoNewline
        return
    }
    
    # Interactive Help Viewer with Invoke-SpectreLive
    # Ratios are king, not sure I can resize without them
    $initialCommandListContent = Write-SpectreHost "[grey]Loading command list...[/]" -PassThru | Format-SpectrePanel -Header "[bold]Commands[/]" -Expand -Border Rounded
    $initialRightPanelContent = Write-SpectreHost "[grey]Select a command to see description.[/]" -PassThru | Format-SpectrePanel -Header "[bold]Description[/]" -Expand -Border Rounded

    $commandListPaneLayout = New-SpectreLayout -Name "commandListPane" -Data $initialCommandListContent -Ratio 1
    $rightPaneLayout = New-SpectreLayout -Name "rightPane" -Data $initialRightPanelContent -Ratio 3
    $combinedPanel = New-SpectreLayout -Name "combinedPanel" -Columns @($commandListPaneLayout , $rightPaneLayout) -Ratio 10

    $titleRenderable = Write-SpectreHost "`n[green bold]Cmdlets[/], [blue bold]Functions[/], and [magenta bold]Aliases[/] in $($SelectedModule.Name)" -PassThru | Format-SpectrePadded -Top 0 -Right 0 -Bottom 0 -Left 1
    $instructionsText = "[grey](↑/↓ Navigate | → Select | ← Back | Type to Search | Esc Exit)[/]"
    $instructionsRenderable = Write-SpectreHost $instructionsText -PassThru | Format-SpectrePadded -Top 1 -Right 0 -Bottom 0 -Left 0 | Format-SpectreAligned -HorizontalAlignment Center
    $layout = New-SpectreLayout -Name "root" -Rows @($titleRenderable, $combinedPanel, $instructionsRenderable)

    Invoke-SpectreLive -Data $layout -ScriptBlock {
        param (
            [Spectre.Console.LiveDisplayContext] $LiveContext
        )
        
        # Set default variables for the live UI
        $currentCommandIndex = 0
        $currentHelpOptionIndex = 0
        $currentParameterIndex = 0
        $rightPaneView = 'Description'
        
        $searchString = ""
        $filteredCommandObjects = $allCommandObjects
        $currentCommandObjectForHelp = $null
        $currentParameterObjectForHelp = $null
        $commandParametersForHelp = @() # Holds Parameter objects, sorted with common params last

        # Dynamic sizing based on console height
        $fixedRowsOverhead = 5 # Approximate rows for title, instructions, borders
        $dynamicPageSize = ($Host.UI.RawUI.WindowSize.Height - $fixedRowsOverhead)
        if ($dynamicPageSize -lt 1) {$dynamicPageSize = 1} # Ensure at least 1
        
        $commandListPageSize = $dynamicPageSize
        $commandListScrollOffset = 0

        $helpOptions = @("Examples", "Detailed", "Full", "Online", "Parameters")
        $currentHelpContentLines = @() # Stores text current help view
        $helpContentScrollOffset = 0
        $helpContentPageSize = $dynamicPageSize
        
        $parameterListPageSize = $dynamicPageSize
        $parameterListScrollOffset = 0

        try {
            while ($true) {
                # Recalculate dynamic page sizes if console was resized
                # This doesn't work when shrinking the console, but it does when expanding
                # Will need to revisit to see if I can resolve that issue.
                $newDynamicPageSize = ($Host.UI.RawUI.WindowSize.Height - $fixedRowsOverhead)
                if ($newDynamicPageSize -lt 1) {$newDynamicPageSize = 1}

                if ($newDynamicPageSize -ne $dynamicPageSize) {
                    $dynamicPageSize = $newDynamicPageSize
                    $commandListPageSize = $dynamicPageSize
                    $helpContentPageSize = $dynamicPageSize
                    $parameterListPageSize = $dynamicPageSize
                    
                    # Re-clamp scroll offsets
                    $commandListTotalItemsForClamp = $filteredCommandObjects.Count
                    if ($commandListTotalItemsForClamp -gt 0) {
                        $commandListScrollOffset = [System.Math]::Min($commandListScrollOffset, [System.Math]::Max(0, $commandListTotalItemsForClamp - $commandListPageSize))
                    } else {
                        $commandListScrollOffset = 0
                    }

                    if ($commandParametersForHelp.Count -gt 0 -and $rightPaneView -eq 'ParameterList') {
                        $parameterListScrollOffset = [System.Math]::Min($parameterListScrollOffset, [System.Math]::Max(0, $commandParametersForHelp.Count - $parameterListPageSize))
                    } else {
                        $commandListScrollOffset = 0
                    }
                    if ($currentHelpContentLines.Count -gt 0) {
                        $helpContentScrollOffset = [System.Math]::Min($helpContentScrollOffset, [System.Math]::Max(0, $currentHelpContentLines.Count - $helpContentPageSize))
                    } else {
                        $commandListScrollOffset = 0
                    }
                }

                # Filter command list based on search string
                if ($searchString -ne "") {
                    $filteredCommandObjects = $allCommandObjects | Where-Object { $_.Name -like "*$searchString*" }
                    # Adjust current index and scroll if filter changes
                    if ($currentCommandIndex -ge $filteredCommandObjects.Count -and $filteredCommandObjects.Count -gt 0) {
                        $currentCommandIndex = $filteredCommandObjects.Count - 1  # Select last item
                    } elseif ($filteredCommandObjects.Count -eq 0) {
                        $currentCommandIndex = -1
                    }
                    if ($currentCommandIndex -eq -1 -or $currentCommandIndex -lt $commandListScrollOffset -or $currentCommandIndex -ge ($commandListScrollOffset + $commandListPageSize)) {
                        $commandListScrollOffset = [System.Math]::Max(0, $currentCommandIndex - [System.Math]::Floor($commandListPageSize / 2))
                        if ($commandListTotalItems -gt 0) {
                            $commandListScrollOffset = [System.Math]::Min($commandListScrollOffset, [System.Math]::Max(0, $commandListTotalItems - $commandListPageSize))
                        } else {
                            $commandListScrollOffset = 0
                        }
                    }
                } else {
                    $filteredCommandObjects = $allCommandObjects
                }
                $commandListTotalItems = $filteredCommandObjects.Count

                # Ensure currentCommandIndex is valid
                if ($commandListTotalItems -eq 0) {
                    $currentCommandIndex = -1
                    $commandListScrollOffset = 0
                } elseif ($currentCommandIndex -eq -1 -or $currentCommandIndex -ge $commandListTotalItems) {
                    # If previous selection is now invalid ( after clearing search)
                    $currentCommandIndex = 0
                    $commandListScrollOffset = 0
                }

                # Command List Panel (Left Pane)
                $listItems = New-Object System.Collections.Generic.List[string]
                $commandListPanelHeader = "[bold]($($commandListTotalItems) total)[/]"
                if ($searchString -ne "") {
                    $commandListPanelHeader += " Filter: [yellow]'$($searchString)'[/]"
                }

                if ($commandListTotalItems -gt 0 -and $currentCommandIndex -ne -1) {
                    if ($commandListScrollOffset -gt 0) { $listItems.Add("[grey]  ↑ ...[/]")}

                    $visibleListStartIndex = $commandListScrollOffset
                    $visibleListEndIndex = [System.Math]::Min(($commandListScrollOffset + $commandListPageSize - 1), ($commandListTotalItems - 1))

                    for ($i = $visibleListStartIndex; $i -le $visibleListEndIndex; $i++) {
                        if ($i -lt 0 -or $i -ge $filteredCommandObjects.Count) { continue }
                        $cmd = $filteredCommandObjects[$i]
                        $displayName = $cmd.Name
                        $styledName = switch ($cmd.Type) {
                            'Cmdlet'   { "[green]$displayName[/]" }
                            'Function' { "[blue]$displayName[/]" }
                            'Alias'    { "[magenta]$displayName[/]" }
                            default    { $displayName }
                        }
                        if ($i -eq $currentCommandIndex) { $listItems.Add("[yellow bold]>[/] $($styledName)") } # Highlight selected
                        else { $listItems.Add("  $($styledName)") }
                    }
                    if ($visibleListEndIndex -lt ($commandListTotalItems - 1)) { $listItems.Add("[grey]  ↓ ...[/]")}
                } else {
                    $listItems.Add("[grey] (No commands to display) [/]")
                }
            
                $commandListPanel = $listItems | Format-SpectreRows | Format-SpectrePanel -Header $commandListPanelHeader -Expand -Border Rounded
                $layout["commandListPane"].Update($commandListPanel) | Out-Null
                

                # Right Pane for Command View (Description, Help Options, or Help Content)
                $rightPanelContentRenderable = $null
                $rightPanelHeader = "[bold]Info[/]"

                if ($rightPaneView -eq 'Description') {
                    $rightPanelHeader = "[bold]Description[/]"
                    if ($currentCommandIndex -ge 0 -and $currentCommandIndex -lt $filteredCommandObjects.Count) {
                        $currentCmdForDesc = $filteredCommandObjects[$currentCommandIndex]
                        $rightPanelHeader = "[bold]Description for $($currentCmdForDesc.Name)[/]"
                        $descriptionText = if ($currentCmdForDesc.Synopsis -and $currentCmdForDesc.Synopsis -ne "") {
                            $currentCmdForDesc.Synopsis
                        } elseif ($currentCmdForDesc.Type -eq 'Alias' -and $currentCmdForDesc.Definition) {
                            "Alias for: $($currentCmdForDesc.Definition)"
                        } else { "No synopsis available." }
                        $rightPanelContentRenderable = ($descriptionText | Get-SpectreEscapedText | Format-SpectrePanel -Header $rightPanelHeader -Expand -Border Rounded)
                    } else {
                        $rightPanelContentRenderable = (Write-SpectreHost "[grey]No command selected or found.[/]" -PassThru | Format-SpectrePanel -Header $rightPanelHeader -Expand -Border Rounded)
                    }
                } elseif ($rightPaneView -eq 'HelpOptions') {
                    $rightPanelHeader = "[bold]Help Options for $($currentCommandObjectForHelp.Name)[/]"
                    $helpOptionListItems = for ($i = 0; $i -lt $helpOptions.Count; $i++) {
                        if ($i -eq $currentHelpOptionIndex) { "[yellow bold]>[/] $($helpOptions[$i])" }
                        else { "  $($helpOptions[$i])" }
                    }
                    $rightPanelContentRenderable = ($helpOptionListItems | Format-SpectreRows | Format-SpectrePanel -Header $rightPanelHeader -Expand -Border Rounded)
                
                } elseif ($rightPaneView -eq 'ParameterList') {
                    $rightPanelHeader = "[bold]Parameters for $($currentCommandObjectForHelp.Name)[/]"
                    $paramListItems = New-Object System.Collections.Generic.List[string]
                    if ($commandParametersForHelp.Count -gt 0) {
                        if ($parameterListScrollOffset -gt 0) { $paramListItems.Add("[grey]  ↑ ...[/]")}
                        
                        $visibleParamListStartIndex = $parameterListScrollOffset
                        $visibleParamListEndIndex = [System.Math]::Min(($parameterListScrollOffset + $parameterListPageSize - 1), ($commandParametersForHelp.Count - 1))

                        for ($p = $visibleParamListStartIndex; $p -le $visibleParamListEndIndex; $p++) {
                            if ($p -lt 0 -or $p -ge $commandParametersForHelp.Count) { continue }
                            $paramMetadata = $commandParametersForHelp[$p]
                            $paramName = $paramMetadata.Name
                            $styledParamName = if ($commonParameterNames -contains $paramName) { # Style common parameters
                                "[grey]$paramName[/]"
                            } else {
                                $paramName
                            }
                            if ($p -eq $currentParameterIndex) { $paramListItems.Add("[yellow bold]>[/] $($styledParamName)") }
                            else { $paramListItems.Add("  $($styledParamName)") }
                        }
                        if ($visibleParamListEndIndex -lt ($commandParametersForHelp.Count - 1)) { $paramListItems.Add("[grey]  ↓ ...[/]")}
                    } else {
                        $paramListItems.Add("[grey](No parameters found or command does not support parameters)[/]")
                    }
                    $rightPanelContentRenderable = ($paramListItems | Format-SpectreRows | Format-SpectrePanel -Header $rightPanelHeader -Expand -Border Rounded)

                } elseif ($rightPaneView -eq 'HelpContent' -or $rightPaneView -eq 'ParameterHelpContent') {
                    # Determine header based on whether it's general help or parameter-specific help
                    if ($rightPaneView -eq 'ParameterHelpContent') {
                        $rightPanelHeader = "[bold]Parameter: $($currentParameterObjectForHelp.Name) in $($currentCommandObjectForHelp.Name)[/]"
                    } else { # HelpContent
                        $rightPanelHeader = "[bold]Help: $($currentCommandObjectForHelp.Name) - $($helpOptions[$currentHelpOptionIndex])[/]"
                    }
                    
                    # Display scrolled content
                    $visibleHelpLines = New-Object System.Collections.Generic.List[string]
                    if ($currentHelpContentLines.Count -gt 0) {
                        if ($helpContentScrollOffset -gt 0) { $visibleHelpLines.Add("[grey]  ↑ ...[/]")}
                        
                        $helpViewEndIndex = [System.Math]::Min(($helpContentScrollOffset + $helpContentPageSize - 1), ($currentHelpContentLines.Count - 1))
                        for ($l = $helpContentScrollOffset; $l -le $helpViewEndIndex; $l++) {
                            if ($l -ge 0 -and $l -lt $currentHelpContentLines.Count) {
                                $visibleHelpLines.Add($currentHelpContentLines[$l])
                            }
                        }

                        if ($helpViewEndIndex -lt ($currentHelpContentLines.Count - 1)) { $visibleHelpLines.Add("[grey]  ↓ ...[/]")}
                    } else {
                        $visibleHelpLines.Add($currentHelpContent)
                    }
                    $rightPanelContentRenderable = ($visibleHelpLines | Format-SpectreRows | Format-SpectrePanel -Header $rightPanelHeader -Expand -Border Rounded)
                }
                
                $layout["rightPane"].Update($rightPanelContentRenderable) | Out-Null
            
                $LiveContext.Refresh()

                # Input handling
                if (-not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 50; continue }
                $keyInfo = [Console]::ReadKey($true)
                
                if ($keyInfo.Key -eq [System.ConsoleKey]::Escape) { return $null }

                # Type to Search but only when in Description view
                if ($rightPaneView -eq 'Description' -and
                    (($keyInfo.KeyChar -ge 'a' -and $keyInfo.KeyChar -le 'z') -or
                    ($keyInfo.KeyChar -ge 'A' -and $keyInfo.KeyChar -le 'Z') -or
                    ($keyInfo.KeyChar -ge '0' -and $keyInfo.KeyChar -le '9') -or
                    $keyInfo.KeyChar -eq '-' -or $keyInfo.KeyChar -eq '_' ) ) {
                    $searchString += $keyInfo.KeyChar
                    $currentCommandIndex = 0
                    $commandListScrollOffset = 0
                    continue # Re-render with new search
                }
                
                # More Input Handling!
                if ($rightPaneView -eq 'Description') {
                    switch ($keyInfo.Key) {
                        ([System.ConsoleKey]::UpArrow) {
                            if ($currentCommandIndex -gt 0) {
                                $currentCommandIndex--
                                if ($currentCommandIndex -lt $commandListScrollOffset) {
                                    $commandListScrollOffset = $currentCommandIndex # Snap to top
                                }
                            }
                        }
                        ([System.ConsoleKey]::DownArrow) {
                            if ($commandListTotalItems -gt 0 -and $currentCommandIndex -lt ($commandListTotalItems - 1)) {
                                $currentCommandIndex++
                                if ($currentCommandIndex -ge ($commandListScrollOffset + $commandListPageSize)) {
                                    $commandListScrollOffset++ # Scroll down one line
                                }
                            }
                        }
                        ([System.ConsoleKey]::RightArrow) {
                            if ($currentCommandIndex -ge 0 -and $currentCommandIndex -lt $filteredCommandObjects.Count) {
                                $currentCommandObjectForHelp = $filteredCommandObjects[$currentCommandIndex]
                                $rightPaneView = 'HelpOptions'
                                $currentHelpOptionIndex = 0
                                $searchString = "" # Clear search when moving to help
                            }
                        }
                        ([System.ConsoleKey]::LeftArrow) { # Backspace for search or exit
                            if ($searchString.Length -gt 0) {
                                $searchString = $searchString.Substring(0, $searchString.Length - 1)
                                $currentCommandIndex = 0
                                $commandListScrollOffset = 0
                            } else {
                                return $null
                            }
                        }
                        ([System.ConsoleKey]::Backspace) {
                            if ($searchString.Length -gt 0) {
                                $searchString = $searchString.Substring(0, $searchString.Length - 1)
                                $currentCommandIndex = 0
                                $commandListScrollOffset = 0
                            }
                        }
                        ([System.ConsoleKey]::Enter) { # Same as RightArrow
                            if ($currentCommandIndex -ge 0 -and $currentCommandIndex -lt $filteredCommandObjects.Count) {
                                $currentCommandObjectForHelp = $filteredCommandObjects[$currentCommandIndex]
                                $rightPaneView = 'HelpOptions'
                                $currentHelpOptionIndex = 0
                                $searchString = ""
                            }
                        }
                    }
                } elseif ($rightPaneView -eq 'HelpOptions') {
                    switch ($keyInfo.Key) {
                        ([System.ConsoleKey]::UpArrow) {
                            if ($currentHelpOptionIndex -gt 0) { $currentHelpOptionIndex-- }
                        }
                        ([System.ConsoleKey]::DownArrow) {
                            if ($currentHelpOptionIndex -lt ($helpOptions.Count - 1)) { $currentHelpOptionIndex++ }
                        }
                        ([System.ConsoleKey]::RightArrow) {
                            $selectedHelpType = $helpOptions[$currentHelpOptionIndex]
                            $currentHelpContentLines = @("[grey]Fetching help...[/]") # Placeholder
                            $helpContentScrollOffset = 0
                            
                            if ($selectedHelpType -eq "Parameters") { # Handle "Parameters" selection
                                $allParams = $currentCommandObjectForHelp.CommandInfo.Parameters.Values
                                $nonCommonParams = $allParams | Where-Object { $commonParameterNames -notcontains $_.Name } | Sort-Object Name
                                $commonParamsFromCmd = $allParams | Where-Object { $commonParameterNames -contains $_.Name } | Sort-Object Name
                                $commandParametersForHelp = $nonCommonParams + $commonParamsFromCmd # Non-common first

                                $currentParameterIndex = 0
                                $parameterListScrollOffset = 0
                                $rightPaneView = 'ParameterList'
                            } elseif ($selectedHelpType -eq "Online") {
                                $currentHelpContentLines = @("[yellow]Press Right Arrow or Enter to open online help (if available), or Left Arrow to go back.[/]")
                                $rightPaneView = 'HelpContent'
                            } else { # For Examples, Detailed, Full
                                $rightPaneView = 'HelpContent'
                                $LiveContext.Refresh() # Show "Fetching help..."
                                try {
                                    $helpText = ""
                                    switch($selectedHelpType) {
                                        "Examples" { $helpText = Get-Help $currentCommandObjectForHelp.CommandInfo -Examples | Out-String }
                                        "Detailed" { $helpText = Get-Help $currentCommandObjectForHelp.CommandInfo -Detailed | Out-String }
                                        "Full"     { $helpText = Get-Help $currentCommandObjectForHelp.CommandInfo -Full | Out-String }
                                    }
                                    $currentHelpContentLines = ($helpText | Get-SpectreEscapedText) -split "`r?`n"
                                    if ($currentHelpContentLines.Count -eq 0 -or ($currentHelpContentLines.Count -eq 1 -and [string]::IsNullOrWhiteSpace($currentHelpContentLines[0]))) {
                                        $currentHelpContentLines = @("[grey](No content for this help type)[/]")
                                    }
                                } catch {
                                    $currentHelpContentLines = @(("[red]Could not retrieve help: $($_.Exception.Message | Get-SpectreEscapedText)[/]" -split "`r?`n"))
                                }
                            }
                        }
                        ([System.ConsoleKey]::LeftArrow) { # Go back to Description view
                            $rightPaneView = 'Description'
                            $currentCommandObjectForHelp = $null
                            $currentHelpContentLines = @(); $helpContentScrollOffset = 0
                        }
                        ([System.ConsoleKey]::Enter) { # Same as RightArrow
                            $selectedHelpType = $helpOptions[$currentHelpOptionIndex]
                            $currentHelpContentLines = @("[grey]Fetching help...[/]")
                            $helpContentScrollOffset = 0
                            
                            if ($selectedHelpType -eq "Parameters") {
                                $allParams = $currentCommandObjectForHelp.CommandInfo.Parameters.Values
                                $nonCommonParams = $allParams | Where-Object { $commonParameterNames -notcontains $_.Name } | Sort-Object Name
                                $commonParamsFromCmd = $allParams | Where-Object { $commonParameterNames -contains $_.Name } | Sort-Object Name
                                $commandParametersForHelp = $nonCommonParams + $commonParamsFromCmd

                                $currentParameterIndex = 0
                                $parameterListScrollOffset = 0
                                $rightPaneView = 'ParameterList'
                            } elseif ($selectedHelpType -eq "Online") {
                                $currentHelpContentLines = @("[yellow]Press Right Arrow or Enter to open online help (if available), or Left Arrow to go back.[/]")
                                $rightPaneView = 'HelpContent'
                            } else {
                                $rightPaneView = 'HelpContent'
                                $LiveContext.Refresh()
                                try {
                                    $helpText = ""
                                    switch($selectedHelpType) {
                                        "Examples" { $helpText = Get-Help $currentCommandObjectForHelp.CommandInfo -Examples | Out-String }
                                        "Detailed" { $helpText = Get-Help $currentCommandObjectForHelp.CommandInfo -Detailed | Out-String }
                                        "Full"     { $helpText = Get-Help $currentCommandObjectForHelp.CommandInfo -Full | Out-String }
                                    }
                                    $currentHelpContentLines = ($helpText | Get-SpectreEscapedText) -split "`r?`n"
                                    if ($currentHelpContentLines.Count -eq 0 -or ($currentHelpContentLines.Count -eq 1 -and [string]::IsNullOrWhiteSpace($currentHelpContentLines[0]))) {
                                        $currentHelpContentLines = @("[grey](No content for this help type)[/]")
                                    }
                                } catch {
                                    $currentHelpContentLines = @(("[red]Could not retrieve help: $($_.Exception.Message | Get-SpectreEscapedText)[/]" -split "`r?`n"))
                                }
                            }
                        }
                    }
                } elseif ($rightPaneView -eq 'ParameterList') {
                    switch ($keyInfo.Key) {
                        ([System.ConsoleKey]::UpArrow) {
                            if ($currentParameterIndex -gt 0) {
                                $currentParameterIndex--
                                if ($currentParameterIndex -lt $parameterListScrollOffset) {
                                    $parameterListScrollOffset = $currentParameterIndex
                                }
                            }
                        }
                        ([System.ConsoleKey]::DownArrow) {
                            if ($commandParametersForHelp.Count -gt 0 -and $currentParameterIndex -lt ($commandParametersForHelp.Count - 1)) {
                                $currentParameterIndex++
                                if ($currentParameterIndex -ge ($parameterListScrollOffset + $parameterListPageSize)) {
                                    $parameterListScrollOffset++
                                }
                            }
                        }
                        ([System.ConsoleKey]::RightArrow) {
                            if ($commandParametersForHelp.Count -gt 0 -and $currentParameterIndex -ge 0 -and $currentParameterIndex -lt $commandParametersForHelp.Count) {
                                $currentParameterObjectForHelp = $commandParametersForHelp[$currentParameterIndex] # This is ParameterMetadata
                                $currentHelpContentLines = @("[grey]Fetching parameter help...[/]")
                                $helpContentScrollOffset = 0
                                $rightPaneView = 'ParameterHelpContent'
                                $LiveContext.Refresh()
                                try {
                                    $paramHelpText = Get-Help $currentCommandObjectForHelp.Name -Parameter $currentParameterObjectForHelp.Name | Out-String
                                    if ([string]::IsNullOrWhiteSpace($paramHelpText) -and $currentParameterObjectForHelp.HelpMessage) { # Fallback
                                        $paramHelpText = $currentParameterObjectForHelp.HelpMessage
                                    }

                                    if (-not [string]::IsNullOrWhiteSpace($paramHelpText)) {
                                        $currentHelpContentLines = ($paramHelpText | Get-SpectreEscapedText) -split "`r?`n"
                                    } else {
                                        $currentHelpContentLines = @("[grey](No specific help message found for this parameter.)[/]")
                                    }
                                } catch {
                                    $currentHelpContentLines = @(("[red]Could not retrieve help for parameter '$($currentParameterObjectForHelp.Name)': $($_.Exception.Message | Get-SpectreEscapedText)[/]" -split "`r?`n"))
                                }
                            }
                        }
                        ([System.ConsoleKey]::LeftArrow) { # Go back to Help Options
                            $rightPaneView = 'HelpOptions'
                            $commandParametersForHelp = @()
                            $currentParameterObjectForHelp = $null
                        }
                        ([System.ConsoleKey]::Enter) { # Same as RightArrow
                            if ($commandParametersForHelp.Count -gt 0 -and $currentParameterIndex -ge 0 -and $currentParameterIndex -lt $commandParametersForHelp.Count) {
                                $currentParameterObjectForHelp = $commandParametersForHelp[$currentParameterIndex]
                                $currentHelpContentLines = @("[grey]Fetching parameter help...[/]")
                                $helpContentScrollOffset = 0
                                $rightPaneView = 'ParameterHelpContent'
                                $LiveContext.Refresh()
                                try {
                                    $paramHelpText = Get-Help $currentCommandObjectForHelp.Name -Parameter $currentParameterObjectForHelp.Name | Out-String
                                    if ([string]::IsNullOrWhiteSpace($paramHelpText) -and $currentParameterObjectForHelp.HelpMessage) {
                                        $paramHelpText = $currentParameterObjectForHelp.HelpMessage
                                    }
                                    if (-not [string]::IsNullOrWhiteSpace($paramHelpText)) {
                                        $currentHelpContentLines = ($paramHelpText | Get-SpectreEscapedText) -split "`r?`n"
                                    } else {
                                        $currentHelpContentLines = @("[grey](No specific help message found for this parameter.)[/]")
                                    }
                                } catch {
                                    $currentHelpContentLines = @(("[red]Could not retrieve help for parameter '$($currentParameterObjectForHelp.Name)': $($_.Exception.Message | Get-SpectreEscapedText)[/]" -split "`r?`n"))
                                }
                            }
                        }
                    }
                } elseif ($rightPaneView -eq 'HelpContent' -or $rightPaneView -eq 'ParameterHelpContent') {
                    switch ($keyInfo.Key) {
                        ([System.ConsoleKey]::LeftArrow) { # Go back to previous view
                            if ($rightPaneView -eq 'ParameterHelpContent') {
                                $rightPaneView = 'ParameterList'
                            } else { # HelpContent
                                $rightPaneView = 'HelpOptions'
                            }
                            $currentHelpContentLines = @(); $helpContentScrollOffset = 0 # Clear content
                        }
                        ([System.ConsoleKey]::RightArrow) { # Only for Online help
                            if ($rightPaneView -eq 'HelpContent' -and $helpOptions[$currentHelpOptionIndex] -eq "Online") {
                                try { Get-Help $currentCommandObjectForHelp.CommandInfo -Online }
                                catch { $currentHelpContentLines = @("[red]Could not retrieve online help. Press Left to go back.[/]") }
                                # Don't automatically go back, let user see message if it fails.
                            }
                        }
                        ([System.ConsoleKey]::Enter) { # Only for Online help
                            if ($rightPaneView -eq 'HelpContent' -and $helpOptions[$currentHelpOptionIndex] -eq "Online") {
                                try { Get-Help $currentCommandObjectForHelp.CommandInfo -Online }
                                catch { $currentHelpContentLines = @("[red]Could not retrieve online help. Press Left to go back.[/]") }
                            }
                        }
                        ([System.ConsoleKey]::UpArrow) { # Scroll up
                            if ($helpContentScrollOffset -gt 0) { $helpContentScrollOffset-- }
                        }
                        ([System.ConsoleKey]::DownArrow) { # Scroll down
                            if (($helpContentScrollOffset + $helpContentPageSize) -lt $currentHelpContentLines.Count) {
                                $helpContentScrollOffset++
                            }
                        }
                    }
                }
            } # End while ($true)
        }
        catch {
            # Catch any unexpected errors during the live display
            Write-SpectreHost "[bold red]Error within Invoke-SpectreLive: $($_.Exception.ToString() | Get-SpectreEscapedText)[/]"
            Read-SpectrePause -Message "[grey]Press Enter to acknowledge error and return...[/]" -NoNewline
            return $null
        }
        # This return should ideally not be reached if Escape is the main exit.
        return $null
    } # End Invoke-SpectreLive ScriptBlock

    Clear-Host # Clean up the console after exiting the live display
}