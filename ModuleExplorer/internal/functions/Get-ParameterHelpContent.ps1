<#
.SYNOPSIS
    Fetches and formats parameter-specific help content into Spectre-safe string lines.

.DESCRIPTION
    Get-ParameterHelpContent extracts the parameter help-fetching block that was
    duplicated inside both the RightArrow and Enter key handlers for the ParameterList
    view in Show-ModuleCommandViewer.

    It calls Get-Help -Parameter to retrieve the help for a specific parameter, falls back
    to the ParameterMetadata.HelpMessage property if Get-Help returns nothing, and then
    escapes the result with Get-SpectreEscapedText before splitting into lines.

.PARAMETER CommandName
    The name of the command whose parameter help is being retrieved (string, not
    CommandInfo — Get-Help -Parameter requires the command name).

.PARAMETER ParameterName
    The name of the parameter to look up.

.PARAMETER FallbackHelpMessage
    Optional. A pre-fetched HelpMessage string from ParameterMetadata.HelpMessage.
    Used when Get-Help -Parameter returns empty content.

.OUTPUTS
    System.String[]
    An array of Spectre-escaped strings, one element per line.
    Never returns $null — returns a one-element grey placeholder when no content is found.

.EXAMPLE
    $lines = Get-ParameterHelpContent `
                -CommandName   $state.CurrentCommand.Name `
                -ParameterName $selectedParam.Name `
                -FallbackHelpMessage $selectedParam.HelpMessage
#>
function Get-ParameterHelpContent {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [string]$ParameterName,

        [string]$FallbackHelpMessage
    )

    try {
        $rawText = Get-Help $CommandName -Parameter $ParameterName | Out-String

        # Fallback to ParameterMetadata.HelpMessage when Get-Help returns nothing
        if ([string]::IsNullOrWhiteSpace($rawText) -and -not [string]::IsNullOrWhiteSpace($FallbackHelpMessage)) {
            $rawText = $FallbackHelpMessage
        }

        if (-not [string]::IsNullOrWhiteSpace($rawText)) {
            return ($rawText | Get-SpectreEscapedText) -split "`r?`n"
        }

        return @('[grey](No specific help message found for this parameter.)[/]')
    }
    catch {
        $escapedName = $ParameterName | Get-SpectreEscapedText
        $escapedMsg  = $_.Exception.Message | Get-SpectreEscapedText
        return @("[red]Could not retrieve help for parameter '$escapedName': $escapedMsg[/]")
    }
}
