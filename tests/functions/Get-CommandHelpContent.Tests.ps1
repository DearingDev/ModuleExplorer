BeforeDiscovery {
    if (-not (Get-Module ModuleExplorer)) {
        Import-Module (Join-Path $PSScriptRoot '..', '..', 'ModuleExplorer', 'ModuleExplorer.psm1') -Force
    }
}

Describe 'Get-CommandHelpContent' {
    InModuleScope ModuleExplorer {

        Context 'Online help type' {
            It 'returns a single prompt string without calling Get-Help' {
                Mock Get-Help { throw 'Should not be called for Online' }
                $result = @(Get-CommandHelpContent -HelpType 'Online' -CommandInfo 'Get-Item')
                $result | Should -HaveCount 1
                $result[0] | Should -Match 'online help'
            }
        }

        Context 'Standard help types with content' {
            BeforeEach {
                Mock Get-Help { 'Some help content returned from Get-Help' }
                Mock Get-SpectreEscapedText { param([Parameter(ValueFromPipeline)][string]$text) process { $text } }
            }

            It 'returns lines for Examples help' {
                $result = Get-CommandHelpContent -HelpType 'Examples' -CommandInfo 'Get-Item'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'returns lines for Detailed help' {
                $result = Get-CommandHelpContent -HelpType 'Detailed' -CommandInfo 'Get-Item'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'returns lines for Full help' {
                $result = Get-CommandHelpContent -HelpType 'Full' -CommandInfo 'Get-Item'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'never returns $null' {
                $result = Get-CommandHelpContent -HelpType 'Examples' -CommandInfo 'Get-Item'
                $result | Should -Not -BeNullOrEmpty
            }
        }

        Context 'Empty help content' {
            BeforeEach {
                Mock Get-Help { '' }
                Mock Get-SpectreEscapedText { param([Parameter(ValueFromPipeline)][string]$text) process { $text } }
            }

            It 'returns a single grey placeholder when Get-Help returns empty string' {
                $result = @(Get-CommandHelpContent -HelpType 'Examples' -CommandInfo 'Get-Item')
                $result | Should -HaveCount 1
                $result[0] | Should -Match '\[grey\]'
                $result[0] | Should -Match 'No content'
            }
        }

        Context 'Get-Help throws an exception' {
            BeforeEach {
                Mock Get-Help { throw 'Help retrieval failed' }
                Mock Get-SpectreEscapedText { param([Parameter(ValueFromPipeline)][string]$text) process { $text } }
            }

            It 'returns a single red error line' {
                $result = @(Get-CommandHelpContent -HelpType 'Examples' -CommandInfo 'FakeCommand')
                $result | Should -HaveCount 1
                $result[0] | Should -Match '\[red\]'
            }

            It 'never throws' {
                { Get-CommandHelpContent -HelpType 'Full' -CommandInfo 'BadCmd' } | Should -Not -Throw
            }
        }
    }
}

