<#
.SYNOPSIS
    Returns a command's parameters sorted with non-common parameters first.

.DESCRIPTION
    Get-SortedParameterList extracts the parameter-sorting logic that was duplicated
    three times inside Show-ModuleCommandViewer (once in $handleParameterListInput,
    once in the RightArrow handler for HelpOptions, and once in the Enter handler for
    HelpOptions).

    The sort order is:
      1. Non-common parameters, alphabetically by name.
      2. Common parameters (Verbose, Debug, ErrorAction, etc.), alphabetically by name.

    This places the most relevant parameters at the top of the list while keeping the
    common PowerShell parameters accessible but visually separated (callers typically
    render them in grey).

.PARAMETER Parameters
    The .Values collection from a CommandInfo.Parameters dictionary
    (System.Management.Automation.ParameterMetadata objects).

.OUTPUTS
    System.Management.Automation.ParameterMetadata[]
    Sorted array of ParameterMetadata objects. Returns an empty array if the command
    has no parameters.

.EXAMPLE
    $sorted = Get-SortedParameterList -Parameters $commandInfo.Parameters.Values
    # Use $sorted as the $commandParametersForHelp list in the viewer
#>
function Get-SortedParameterList {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ParameterMetadata[]])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $Parameters   # Accepts .Values from CommandInfo.Parameters (ICollection)
    )

    $commonNames = $script:UIConfig.CommonParameters

    $ordered = [System.Collections.Generic.List[System.Management.Automation.ParameterMetadata]]::new()

    $nonCommon = @(
        $Parameters |
            Where-Object { $commonNames -notcontains $_.Name } |
            Sort-Object Name
    )
    if ($nonCommon) { $ordered.AddRange([System.Management.Automation.ParameterMetadata[]]$nonCommon) }

    $common = @(
        $Parameters |
            Where-Object { $commonNames -contains $_.Name } |
            Sort-Object Name
    )
    if ($common) { $ordered.AddRange([System.Management.Automation.ParameterMetadata[]]$common) }

    return $ordered.ToArray()
}
