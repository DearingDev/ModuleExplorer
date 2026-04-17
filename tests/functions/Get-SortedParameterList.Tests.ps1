BeforeDiscovery {
    if (-not (Get-Module ModuleExplorer)) {
        Import-Module (Join-Path $PSScriptRoot '..', '..', 'ModuleExplorer', 'ModuleExplorer.psm1') -Force
    }
}

Describe 'Get-SortedParameterList' {
    InModuleScope ModuleExplorer {

        BeforeAll {
            # Get-ChildItem has both command-specific and common parameters on all platforms.
            $script:allParams = (Get-Command Get-ChildItem).Parameters.Values

            $script:commonNames = @(
                'Verbose', 'Debug', 'ErrorAction', 'ErrorVariable', 'WarningAction',
                'WarningVariable', 'OutBuffer', 'OutVariable', 'PipelineVariable',
                'InformationAction', 'InformationVariable', 'ProgressAction'
            )
        }

        It 'returns an array of ParameterMetadata objects' {
            $result = Get-SortedParameterList -Parameters $allParams
            $result | Should -Not -BeNullOrEmpty
            $result[0] | Should -BeOfType [System.Management.Automation.ParameterMetadata]
        }

        It 'places all non-common parameters before any common parameter' {
            $result = Get-SortedParameterList -Parameters $allParams

            $firstCommonIndex   = [int]::MaxValue
            $lastNonCommonIndex = -1

            for ($i = 0; $i -lt $result.Count; $i++) {
                if ($result[$i].Name -in $commonNames) {
                    if ($i -lt $firstCommonIndex) { $firstCommonIndex = $i }
                } else {
                    if ($i -gt $lastNonCommonIndex) { $lastNonCommonIndex = $i }
                }
            }

            # Only assert ordering when both groups are present
            if ($firstCommonIndex -ne [int]::MaxValue -and $lastNonCommonIndex -ne -1) {
                $lastNonCommonIndex | Should -BeLessThan $firstCommonIndex
            }
        }

        It 'sorts non-common parameters alphabetically by name' {
            $result   = Get-SortedParameterList -Parameters $allParams
            $nonCommon = @($result | Where-Object { $_.Name -notin $commonNames })
            $sorted    = @($nonCommon | Sort-Object Name)
            for ($i = 0; $i -lt $nonCommon.Count; $i++) {
                $nonCommon[$i].Name | Should -Be $sorted[$i].Name
            }
        }

        It 'sorts common parameters alphabetically by name' {
            $result = Get-SortedParameterList -Parameters $allParams
            $common  = @($result | Where-Object { $_.Name -in $commonNames })
            $sorted  = @($common | Sort-Object Name)
            for ($i = 0; $i -lt $common.Count; $i++) {
                $common[$i].Name | Should -Be $sorted[$i].Name
            }
        }

        It 'returns an empty array for null input' {
            $result = Get-SortedParameterList -Parameters $null
            $result.Count | Should -Be 0
        }

        It 'returns an empty array for an empty collection' {
            $result = Get-SortedParameterList -Parameters @()
            $result.Count | Should -Be 0
        }

        It 'preserves all parameters — none are dropped' {
            $result = Get-SortedParameterList -Parameters $allParams
            $result.Count | Should -Be $allParams.Count
        }
    }
}
