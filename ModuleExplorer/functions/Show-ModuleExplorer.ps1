<#
.SYNOPSIS
Interactively explores available PowerShell modules and their commands.

.DESCRIPTION
The Show-ModuleExplorer cmdlet provides an interactive, terminal-based user interface
to browse through PowerShell modules installed or available on the system.
Users can select a module from the list to view its commands using the Show-ModuleCommandViewer function.

The interface displays "Module Explorer" as a title and lists all available modules.
You can filter the list of modules by providing a search string to the -Filter parameter.
The list also includes options to "Refresh List" and "<-- Exit" the explorer.

This function utilizes PwshSpectreConsole cmdlets for a rich interactive experience.

.PARAMETER Filter
An optional string used to filter the list of displayed modules.
The function will search for modules whose names matches the filter string.

Type: String
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: True

.EXAMPLE
Get-Process C:\> Show-ModuleExplorer

Description:
Launches the Module Explorer, displaying all available PowerShell modules.
You can then navigate and select a module to view its commands.

.EXAMPLE
Get-Process C:\> Show-ModuleExplorer -Filter "BurntToast"

Description:
Launches the Module Explorer and filters the initial list to show only modules
named "BurnToast".

.NOTES
Upon selecting a module, this function calls `Show-ModuleCommandViewer` to display
the commands within that module.

The explorer allows for refreshing the module list to reflect any changes (installs/uninstalls)
made while the explorer is running.

Navigation within the selection list is done using arrow keys and Enter.
The selection prompt also supports typing to filter the choices in real-time.

.INPUTS
None
This function does not accept input from the pipeline.

.OUTPUTS
None
This function does not return any objects to the pipeline.
It provides an interactive display in the console.

.LINK
None
#>
function Show-ModuleExplorer {
    [CmdletBinding()]
    param(
        [string]$Filter # Optional filter for module names
    )

    try {
        $moduleLookup = @{} # Initialize hashtable to map display names to module objects
        $minModulesForCategory = 10
        $hideGroupedModules = $false

        while ($true) {
            Clear-Host
            Write-SpectreFigletText -Text "Module Explorer" -Alignment "Center"

            $moduleQuery = @{ ListAvailable = $true }
            if ($Filter) {
                $moduleQuery.Name = $Filter
            }

            # Invoke-SpectreCommandWithStatus -ScriptBlock { $availableModules = Get-Module @moduleQuery |
            #     Select-Object Name, Version, Path, ModuleBase, RootModule,
            #     @{Name = 'Prefix'; Expression = { ($_.Name -split '\.')[0] } } |
            #     Sort-Object Name
            #     $availableModules
            # } -Title "Loading PowerShell Modules..." -Spinner "Shark"

            $availableModules = Get-Module @moduleQuery |
                Select-Object Name, Version, Path, ModuleBase, RootModule,
                @{Name = 'Prefix'; Expression = { ($_.Name -split '\.')[0] } } |
                Sort-Object Name
                $availableModul

            $categories = $availableModules |
                Group-object Prefix |
                Where-object Count -ge $minModulesForCategory

            $exitChoiceString = "[mediumpurple3_1]<-- Exit[/]"
            $refreshChoiceString = "[steelblue1_1]Refresh List[/]"

            if ($hideGroupedModules) {
                $availableModules = $availableModules |
                Where-Object { $_.Prefix -notin $categories.Name } |
                Sort-Object Name
                $groupedModulesChoiceString = "[grey]Show Grouped Modules[/]"
            } else {
                $groupedModulesChoiceString = "[grey]Hide Grouped Modules[/]"
            }

            if (-not $availableModules) {
                Write-SpectreHost "[bold red]No PowerShell modules found.[/]"
                Read-SpectrePause -Message "[grey]Press Enter to continue...[/]" -NoNewline
                return
            }

            # Reset the main loop if modules changes (install/remove)
            $moduleLookup.Clear()
            $moduleChoices = @($exitChoiceString, $refreshChoiceString, $groupedModulesChoiceString)
            $processedDisplayNames = @{}

            foreach ($module in $availableModules) {
                $versionString = if ($module.Version) { "v$($module.Version)" } else { "Version N/A" }
                $displayName = "$($module.Name) ($versionString)"

                if (-not $processedDisplayNames.ContainsKey($displayName)) {
                    $moduleLookup[$displayName] = $module
                    $moduleChoices += $displayName
                    $processedDisplayNames[$displayName] = $true
                }
            }

            $promptTitle = "[yellow bold]Select a PowerShell Module to Explore (or Exit):[/]"
            Write-SpectreRule -Title "[grey]Available Modules: $($availableModules.Count) [/]" -Alignment Center
            $spectreSelectionQuery = @{
                Message = $promptTitle;
                PageSize = 15;
                Choices = $moduleChoices;
                EnableSearch = $true
            }

            $selectedModuleDisplay = Read-SpectreSelection @spectreSelectionQuery

            if (-not $selectedModuleDisplay -or $selectedModuleDisplay -eq $exitChoiceString) {
                Write-SpectreHost "[yellow]Exiting Module Explorer.[/]"
                break
            }

            if ($selectedModuleDisplay -eq $refreshChoiceString) {
                Write-SpectreHost "[italic green]Refreshing module list...[/]"
                continue
            }

            if ($selectedModuleDisplay -eq $groupedModulesChoiceString) {
                Write-SpectreHost "[italic green]Toggling the large modules...[/]"
                if ($hideGroupedModules -eq $true) {
                    Write-SpectreHost "[italic green]Showing the large modules...[/]"
                    $hideGroupedModules = $false
                }
                else {
                    $hideGroupedModules = $true
                    Write-SpectreHost "[italic green]Hiding the large modules...[/]"
                }
                continue
            }

            # Use the lookup table
            $selectedModuleObject = $moduleLookup[$selectedModuleDisplay]

            if (-not $selectedModuleObject) {
                # This condition should not be met if $selectedModuleDisplay is from $moduleChoices
                Write-SpectreHost "[bold red]Error: Could not retrieve details for selected module: '
                    $($selectedModuleDisplay | Get-SpectreEscapedText)'. This is unexpected.[/]"
                Read-SpectrePause -Message "[grey]Press Enter to continue...[/]" -NoNewline
                continue
            }

            Clear-Host
            Show-ModuleCommandViewer -SelectedModule $selectedModuleObject
        } # End of main loop
    }
    catch {
        Write-SpectreHost "[bold red]An unexpected error occurred in Module Explorer:
            $($_.Exception.ToString() | Get-SpectreEscapedText)[/]"
        Read-SpectrePause -Message "[grey]Press Enter to acknowledge error and exit...[/]" -NoNewline
    }
    finally {
        Clear-Host
        Write-SpectreHost "[cyan]Module Explorer session ended.[/]"
    }
}