<#
.SYNOPSIS
    Returns a window into a list of items suitable for rendering in a scrollable TUI pane.

.DESCRIPTION
    Get-ScrollableListView encapsulates the repeated "slice + decorate with scroll indicators"
    pattern that previously existed in three separate locations inside Show-ModuleCommandViewer
    (command list, parameter list, and help-content scrolling).

    The function takes the full item list, the current selection index, the scroll offset, and
    the page size, then returns the slice of lines that should be visible, prepended/appended
    with Spectre Console grey scroll indicators ([grey]  ↑ ...[/] / [grey]  ↓ ...[/]) when
    content extends beyond the visible window.

    An optional -ItemFormatter scriptblock lets callers style each item. The scriptblock
    receives:
        param($Item, [int]$AbsoluteIndex, [bool]$IsSelected)
    and must return a single styled string. If omitted, items are rendered as plain strings
    with a yellow-bold ">" prefix on the selected item.

.PARAMETER Items
    The full, unsliced array of items to display.

.PARAMETER SelectedIndex
    Zero-based index of the currently selected item within the Items array.

.PARAMETER ScrollOffset
    Zero-based index of the first visible item (the current scroll position).

.PARAMETER PageSize
    How many content rows are available for display (excluding scroll-indicator rows).

.PARAMETER ItemFormatter
    Optional scriptblock to style each row. Receives ($Item, $AbsoluteIndex, $IsSelected).
    Must return a single string with Spectre Console markup.

.OUTPUTS
    System.String[]
    An array of Spectre Console markup strings ready to be piped into Format-SpectreRows.

.EXAMPLE
    $lines = Get-ScrollableListView -Items $myItems -SelectedIndex 3 -ScrollOffset 1 -PageSize 10
    $lines | Format-SpectreRows | Format-SpectrePanel -Expand -Border Rounded
#>
function Get-ScrollableListView {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [array]$Items,

        [Parameter(Mandatory)]
        [int]$SelectedIndex,

        [Parameter(Mandatory)]
        [int]$ScrollOffset,

        [Parameter(Mandatory)]
        [int]$PageSize,

        # Optional custom row formatter: param($Item, [int]$Index, [bool]$IsSelected) → string
        [scriptblock]$ItemFormatter
    )

    $result = [System.Collections.Generic.List[string]]::new()

    if ($Items.Count -eq 0 -or $SelectedIndex -lt 0) {
        $result.Add('[grey](No items to display)[/]')
        return $result.ToArray()
    }

    # Scroll-indicator rows consume 1 row each; reserve slots for them so that
    # the visible content area never exceeds PageSize total rows.
    $hasUp   = $ScrollOffset -gt 0
    $contentStartIndex = $ScrollOffset
    # -2 leaves room for both a top and bottom indicator; -1 if only one direction is needed.
    # We pessimistically reserve 2 rows so the slice is stable regardless of scroll position.
    $contentSlotCount = [System.Math]::Max(1, $PageSize - 2)
    $contentEndIndex  = [System.Math]::Min(
        ($contentStartIndex + $contentSlotCount - 1),
        ($Items.Count - 1)
    )
    $hasDown = $contentEndIndex -lt ($Items.Count - 1)

    if ($hasUp)   { $result.Add('[grey]  ↑ ...[/]') }

    for ($i = $contentStartIndex; $i -le $contentEndIndex; $i++) {
        if ($i -lt 0 -or $i -ge $Items.Count) { continue }

        $isSelected = ($i -eq $SelectedIndex)
        $item = $Items[$i]

        if ($null -ne $ItemFormatter) {
            $line = & $ItemFormatter $item $i $isSelected
        } else {
            # Default: plain text with selection cursor
            $text = if ($item -is [string]) { $item } else { $item.ToString() }
            $line = if ($isSelected) { "[yellow bold]>[/] $text" } else { "  $text" }
        }

        $result.Add($line)
    }

    if ($hasDown) { $result.Add('[grey]  ↓ ...[/]') }

    return $result.ToArray()
}
