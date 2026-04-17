<#
.SYNOPSIS
    Creates a data provider for browsing a PowerShell module's commands.

.DESCRIPTION
    Returns a hashtable implementing the data-provider contract expected by
    Show-ModuleCommandViewer. Wraps Get-Command, Get-Help, Get-SortedParameterList,
    Get-CommandHelpContent, and Get-ParameterHelpContent into a uniform interface
    so the viewer can be driven by any compatible provider.

    Provider keys:
      Title           — display string for the viewer title bar
      ItemTypeColors  — hashtable mapping Type name to Spectre color string
      GetItems        — scriptblock()         → PSCustomObject[]
      GetDetailOptions — scriptblock($Item)   → string[]
      GetDetailContent — scriptblock($Item, $Option) → string[]
      GetChildren     — scriptblock($Item, $ChildType) → object[]
      GetChildContent — scriptblock($Item, $Child)    → string[]
      OpenOnlineHelp  — scriptblock($Item)    → (launches browser, no return value)

.PARAMETER ModuleName
    The name of the PowerShell module to expose through this provider.

.OUTPUTS
    [hashtable]
#>
function New-ModuleDataProvider {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    @{
        Title = $ModuleName

        ItemTypeColors = @{
            Cmdlet   = $script:UIConfig.Colors.Cmdlet
            Function = $script:UIConfig.Colors.Function
            Alias    = $script:UIConfig.Colors.Alias
        }

        # Returns all commands in the module as PSCustomObjects with .CommandInfo
        GetItems = {
            $commands = Get-Command -Module $ModuleName | Sort-Object CommandType, Name
            @($commands | ForEach-Object {
                $synopsis = ''
                try {
                    $helpInfo = Get-Help $_.Name -ErrorAction SilentlyContinue
                    if ($helpInfo.Synopsis -is [array]) {
                        $synopsis = ($helpInfo.Synopsis | Select-Object -First 1) -join ' '
                    } elseif ($helpInfo.Synopsis) {
                        $synopsis = $helpInfo.Synopsis
                    }
                } catch {}
                [PSCustomObject]@{
                    Name        = $_.Name
                    Type        = $_.CommandType.ToString()
                    Source      = $_.Source
                    Definition  = $_.Definition
                    Synopsis    = $synopsis
                    CommandInfo = $_
                }
            })
        }.GetNewClosure()

        # Returns the list of help option names for a selected command
        GetDetailOptions = {
            param($SelectedItem)
            $script:UIConfig.HelpOptions
        }

        # Returns formatted help-content lines for a selected help option
        GetDetailContent = {
            param($SelectedItem, [string]$DetailOption)
            Get-CommandHelpContent -HelpType $DetailOption -CommandInfo $SelectedItem.CommandInfo
        }

        # Returns the sorted parameter list for a selected command
        GetChildren = {
            param($SelectedItem, [string]$ChildType)
            Get-SortedParameterList -Parameters $SelectedItem.CommandInfo.Parameters.Values
        }

        # Returns formatted help-content lines for a selected parameter
        GetChildContent = {
            param($SelectedItem, $ChildItem)
            Get-ParameterHelpContent `
                -CommandName         $SelectedItem.Name `
                -ParameterName       $ChildItem.Name `
                -FallbackHelpMessage $ChildItem.HelpMessage
        }

        # Opens the online help page for a selected command in the default browser
        OpenOnlineHelp = {
            param($SelectedItem)
            Get-Help $SelectedItem.CommandInfo -Online
        }
    }
}
