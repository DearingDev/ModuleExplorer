<#
.SYNOPSIS
    Fetches and formats help content for a PowerShell command into Spectre-safe string lines.

.DESCRIPTION
    Get-CommandHelpContent centralizes the help-fetching logic that was previously copy-pasted
    into both the RightArrow and Enter key handlers for the HelpOptions view inside
    Show-ModuleCommandViewer (~50 lines duplicated twice).

    The function retrieves the appropriate help text via Get-Help, escapes it for Spectre
    Console markup using Get-SpectreEscapedText, and splits it into individual lines ready
    to be stored in the $currentHelpContentLines variable.

    For the "Online" help type a special single-item array is returned with an instructional
    prompt rather than fetched content (the actual browser launch is handled separately by
    the input handler).

.PARAMETER HelpType
    The category of help to retrieve. Must be one of: Examples, Detailed, Full, Online.
    (The "Parameters" option is handled separately by Get-SortedParameterList /
    Get-ParameterHelpContent and should not be passed here.)

.PARAMETER CommandInfo
    The original CommandInfo object (e.g. from Get-Command). Passed directly to Get-Help.

.OUTPUTS
    System.String[]
    An array of Spectre-escaped strings, one element per line of formatted help output.
    Never returns $null — returns a one-element grey placeholder on empty/error content.

.EXAMPLE
    $lines = Get-CommandHelpContent -HelpType 'Examples' -CommandInfo $cmd.CommandInfo
    # Store in $currentHelpContentLines for the viewer to render
#>
function Get-CommandHelpContent {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Examples', 'Detailed', 'Full', 'Online')]
        [string]$HelpType,

        [Parameter(Mandatory)]
        $CommandInfo
    )

    # Online help is launched interactively by the input handler; return a prompt string.
    if ($HelpType -eq 'Online') {
        return @('[yellow]Press Right Arrow or Enter to open online help (if available), or Left Arrow to go back.[/]')
    }

    try {
        $helpText = switch ($HelpType) {
            'Examples' { Get-Help $CommandInfo -Examples | Out-String }
            'Detailed' { Get-Help $CommandInfo -Detailed | Out-String }
            'Full'     { Get-Help $CommandInfo -Full     | Out-String }
        }

        $lines = ($helpText | Get-SpectreEscapedText) -split "`r?`n"

        if (-not ($lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            return @('[grey](No content for this help type)[/]')
        }

        return $lines
    }
    catch {
        $escapedMsg = $_.Exception.Message | Get-SpectreEscapedText
        return @("[red]Could not retrieve help: $escapedMsg[/]")
    }
}
