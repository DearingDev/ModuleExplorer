BeforeDiscovery {
    if (-not (Get-Module ModuleExplorer)) {
        Import-Module (Join-Path $PSScriptRoot '..', '..', 'ModuleExplorer', 'ModuleExplorer.psm1') -Force
    }
}

Describe 'Get-ScrollableListView' {
    InModuleScope ModuleExplorer {

        Context 'Empty item list' {
            It 'returns a single no-items placeholder line' {
                $result = @(Get-ScrollableListView -Items @() -SelectedIndex 0 -ScrollOffset 0 -PageSize 10)
                $result | Should -HaveCount 1
                $result[0] | Should -Match 'No items'
            }
        }

        Context 'All items fit within PageSize' {
            It 'returns exactly as many lines as there are items' {
                $items = 'Alpha', 'Beta', 'Gamma'
                $result = Get-ScrollableListView -Items $items -SelectedIndex 0 -ScrollOffset 0 -PageSize 10
                $result | Should -HaveCount 3
            }

            It 'does not add any scroll indicators' {
                $items = 'Alpha', 'Beta', 'Gamma'
                $result = Get-ScrollableListView -Items $items -SelectedIndex 0 -ScrollOffset 0 -PageSize 10
                $result | Should -Not -Contain '[grey]  ↑ ...[/]'
                $result | Should -Not -Contain '[grey]  ↓ ...[/]'
            }

            It 'prefixes the selected item with the yellow-bold cursor' {
                $items = 'Alpha', 'Beta', 'Gamma'
                $result = Get-ScrollableListView -Items $items -SelectedIndex 1 -ScrollOffset 0 -PageSize 10
                $result[1] | Should -Match '^\[yellow bold\]>\[/\]'
            }

            It 'does not add a cursor when SelectedIndex is -1' {
                $items = 'Alpha', 'Beta'
                $result = Get-ScrollableListView -Items $items -SelectedIndex -1 -ScrollOffset 0 -PageSize 10
                $result | ForEach-Object { $_ | Should -Not -Match '^\[yellow bold\]' }
            }
        }

        Context 'Scroll indicators' {
            It 'adds a down indicator when content extends below the visible window' {
                $items = 1..20 | ForEach-Object { "Item$_" }
                $result = Get-ScrollableListView -Items $items -SelectedIndex 0 -ScrollOffset 0 -PageSize 5
                $result[-1] | Should -Be '[grey]  ↓ ...[/]'
            }

            It 'adds an up indicator when ScrollOffset is greater than 0' {
                $items = 1..20 | ForEach-Object { "Item$_" }
                $result = Get-ScrollableListView -Items $items -SelectedIndex 5 -ScrollOffset 5 -PageSize 5
                $result[0] | Should -Be '[grey]  ↑ ...[/]'
            }

            It 'adds both indicators when scrolled into the middle of the list' {
                $items = 1..30 | ForEach-Object { "Item$_" }
                $result = Get-ScrollableListView -Items $items -SelectedIndex 10 -ScrollOffset 5 -PageSize 5
                $result[0]  | Should -Be '[grey]  ↑ ...[/]'
                $result[-1] | Should -Be '[grey]  ↓ ...[/]'
            }
        }

        Context 'Custom ItemFormatter' {
            It 'calls the formatter for each visible item' {
                $items = 'A', 'B', 'C'
                $formatter = { param($item, $index, $isSelected) "fmt:$item" }
                $result = Get-ScrollableListView -Items $items -SelectedIndex 0 -ScrollOffset 0 -PageSize 10 -ItemFormatter $formatter
                $result[0] | Should -Be 'fmt:A'
                $result[1] | Should -Be 'fmt:B'
                $result[2] | Should -Be 'fmt:C'
            }

            It 'passes IsSelected=$true only for the selected item' {
                $items = 'X', 'Y'
                $capturedIsSelected = [System.Collections.Generic.List[object]]::new()
                $formatter = {
                    param($item, $index, $isSelected)
                    $capturedIsSelected.Add($isSelected)
                    $item
                }
                Get-ScrollableListView -Items $items -SelectedIndex 1 -ScrollOffset 0 -PageSize 10 -ItemFormatter $formatter | Out-Null
                $capturedIsSelected[0] | Should -Be $false
                $capturedIsSelected[1] | Should -Be $true
            }
        }
    }
}

