BeforeDiscovery {
    if (-not (Get-Module ModuleExplorer)) {
        Import-Module (Join-Path $PSScriptRoot '..', '..', 'ModuleExplorer', 'ModuleExplorer.psm1') -Force
    }
}

Describe 'Invoke-ViewerInputHandler' {
    InModuleScope ModuleExplorer {

        BeforeAll {
            function New-KeyInfo {
                param(
                    [System.ConsoleKey]$Key,
                    [char]$KeyChar = [char]0
                )
                [System.ConsoleKeyInfo]::new($KeyChar, $Key, $false, $false, $false)
            }

            function New-TestState {
                param([string]$View = 'Description')

                $mockProvider = @{
                    GetDetailOptions = { @('Examples', 'Detailed', 'Full', 'Online', 'Parameters') }
                    GetDetailContent = { @('line one', 'line two') }
                    GetChildren      = { @() }
                    GetChildContent  = { @() }
                    OpenOnlineHelp   = { }
                }

                return @{
                    View                      = $View
                    CommandIndex              = 0
                    CommandListScrollOffset   = 0
                    CommandListPageSize       = 10
                    FilteredCommands          = @(
                        [pscustomobject]@{ Name = 'Get-Foo'; CommandType = 'Function'; Synopsis = 'First'  }
                        [pscustomobject]@{ Name = 'Get-Bar'; CommandType = 'Cmdlet';   Synopsis = 'Second' }
                    )
                    SearchString              = ''
                    HelpOptionIndex           = 0
                    HelpOptions               = @('Examples', 'Detailed', 'Full', 'Online', 'Parameters')
                    ParameterIndex            = 0
                    ParameterListScrollOffset = 0
                    ParameterListPageSize     = 10
                    Parameters                = @()
                    CurrentCommand            = $null
                    CurrentParameter          = $null
                    HelpContentLines          = @()
                    HelpContentScrollOffset   = 0
                    HelpContentPageSize       = 10
                    DataProvider              = $mockProvider
                    LiveContext               = New-Object PSObject | Add-Member -MemberType ScriptMethod -Name Refresh -Value {} -PassThru
                }
            }
        }

        # --- Description view: navigation ---

        Context 'Description view — Up/Down navigation' {
            It 'Up arrow decrements CommandIndex by 1' {
                $state = New-TestState
                $state.CommandIndex = 1
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo UpArrow) -State $state
                $state.CommandIndex | Should -Be 0
            }

            It 'Up arrow does not decrement below 0' {
                $state = New-TestState
                $state.CommandIndex = 0
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo UpArrow) -State $state
                $state.CommandIndex | Should -Be 0
            }

            It 'Down arrow increments CommandIndex by 1' {
                $state = New-TestState
                $state.CommandIndex = 0
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo DownArrow) -State $state
                $state.CommandIndex | Should -Be 1
            }

            It 'Down arrow does not exceed the last item index' {
                $state = New-TestState
                $state.CommandIndex = 1  # last of 2 items
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo DownArrow) -State $state
                $state.CommandIndex | Should -Be 1
            }
        }

        # --- Description view: view transitions ---

        Context 'Description view — transitions' {
            It 'Right arrow transitions to HelpOptions and returns $true' {
                $state  = New-TestState
                $result = Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo RightArrow) -State $state
                $state.View | Should -Be 'HelpOptions'
                $result     | Should -Be $true
            }

            It 'Enter transitions to HelpOptions' {
                $state = New-TestState
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo Enter) -State $state
                $state.View | Should -Be 'HelpOptions'
            }

            It 'Left arrow with empty SearchString returns $null (exit signal)' {
                $state  = New-TestState
                $result = Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $result | Should -BeNullOrEmpty
            }

            It 'Left arrow with a non-empty SearchString removes the last character' {
                $state = New-TestState
                $state.SearchString = 'Get-F'
                $result = Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.SearchString | Should -Be 'Get-'
                $result             | Should -Be $true
            }

            It 'Backspace removes the last character from SearchString' {
                $state = New-TestState
                $state.SearchString = 'abc'
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo Backspace) -State $state
                $state.SearchString | Should -Be 'ab'
            }

            It 'Backspace on empty SearchString leaves it empty' {
                $state = New-TestState
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo Backspace) -State $state
                $state.SearchString | Should -Be ''
            }
        }

        # --- Description view: type-to-search ---

        Context 'Description view — type-to-search' {
            It 'typing a lowercase letter appends it to SearchString' {
                $state = New-TestState
                $key   = [System.ConsoleKeyInfo]::new([char]'g', [System.ConsoleKey]::G, $false, $false, $false)
                Invoke-ViewerInputHandler -KeyInfo $key -State $state
                $state.SearchString | Should -Be 'g'
            }

            It 'typing a digit appends it to SearchString' {
                $state = New-TestState
                $key   = [System.ConsoleKeyInfo]::new([char]'3', [System.ConsoleKey]::D3, $false, $false, $false)
                Invoke-ViewerInputHandler -KeyInfo $key -State $state
                $state.SearchString | Should -Be '3'
            }

            It 'typing resets CommandIndex and ScrollOffset to 0' {
                $state = New-TestState
                $state.CommandIndex            = 1
                $state.CommandListScrollOffset = 2
                $key = [System.ConsoleKeyInfo]::new([char]'x', [System.ConsoleKey]::X, $false, $false, $false)
                Invoke-ViewerInputHandler -KeyInfo $key -State $state
                $state.CommandIndex            | Should -Be 0
                $state.CommandListScrollOffset | Should -Be 0
            }
        }

        # --- HelpOptions view ---

        Context 'HelpOptions view' {
            It 'Up arrow decrements HelpOptionIndex' {
                $state = New-TestState -View 'HelpOptions'
                $state.HelpOptionIndex = 2
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo UpArrow) -State $state
                $state.HelpOptionIndex | Should -Be 1
            }

            It 'Down arrow increments HelpOptionIndex' {
                $state = New-TestState -View 'HelpOptions'
                $state.HelpOptionIndex = 0
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo DownArrow) -State $state
                $state.HelpOptionIndex | Should -Be 1
            }

            It 'Left arrow transitions back to Description' {
                $state = New-TestState -View 'HelpOptions'
                $state.CurrentCommand = $state.FilteredCommands[0]
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.View | Should -Be 'Description'
            }

            It 'Right arrow with "Parameters" selected transitions to ParameterList' {
                $state = New-TestState -View 'HelpOptions'
                $state.CurrentCommand  = $state.FilteredCommands[0]
                $state.HelpOptionIndex = 4  # index of 'Parameters'
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo RightArrow) -State $state
                $state.View | Should -Be 'ParameterList'
            }

            It 'Right arrow with a non-Parameters option transitions to HelpContent' {
                $state = New-TestState -View 'HelpOptions'
                $state.CurrentCommand  = $state.FilteredCommands[0]
                $state.HelpOptionIndex = 0  # 'Examples'
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo RightArrow) -State $state
                $state.View | Should -Be 'HelpContent'
            }

            It 'Enter behaves the same as Right arrow for option selection' {
                $state = New-TestState -View 'HelpOptions'
                $state.CurrentCommand  = $state.FilteredCommands[0]
                $state.HelpOptionIndex = 0
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo Enter) -State $state
                $state.View | Should -Be 'HelpContent'
            }
        }

        # --- HelpContent view ---

        Context 'HelpContent view' {
            It 'Left arrow returns to HelpOptions' {
                $state = New-TestState -View 'HelpContent'
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.View | Should -Be 'HelpOptions'
            }

            It 'Left arrow clears HelpContentLines and resets scroll' {
                $state = New-TestState -View 'HelpContent'
                $state.HelpContentLines       = @('line1', 'line2')
                $state.HelpContentScrollOffset = 1
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.HelpContentLines.Count  | Should -Be 0
                $state.HelpContentScrollOffset | Should -Be 0
            }

            It 'Up arrow decrements HelpContentScrollOffset' {
                $state = New-TestState -View 'HelpContent'
                $state.HelpContentLines        = 1..20 | ForEach-Object { "line$_" }
                $state.HelpContentScrollOffset = 3
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo UpArrow) -State $state
                $state.HelpContentScrollOffset | Should -Be 2
            }

            It 'Up arrow does not decrement scroll below 0' {
                $state = New-TestState -View 'HelpContent'
                $state.HelpContentLines        = @('only line')
                $state.HelpContentScrollOffset = 0
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo UpArrow) -State $state
                $state.HelpContentScrollOffset | Should -Be 0
            }

            It 'Down arrow increments scroll when content extends below' {
                $state = New-TestState -View 'HelpContent'
                $state.HelpContentLines        = 1..20 | ForEach-Object { "line$_" }
                $state.HelpContentScrollOffset = 0
                $state.HelpContentPageSize     = 5
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo DownArrow) -State $state
                $state.HelpContentScrollOffset | Should -Be 1
            }

            It 'Down arrow does not scroll past the last page' {
                $state = New-TestState -View 'HelpContent'
                $state.HelpContentLines        = 1..5 | ForEach-Object { "line$_" }
                $state.HelpContentScrollOffset = 0
                $state.HelpContentPageSize     = 10  # all lines fit
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo DownArrow) -State $state
                $state.HelpContentScrollOffset | Should -Be 0
            }
        }

        # --- ParameterList view ---

        Context 'ParameterList view' {
            It 'Left arrow returns to HelpOptions' {
                $state = New-TestState -View 'ParameterList'
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.View | Should -Be 'HelpOptions'
            }

            It 'Left arrow clears Parameters and CurrentParameter' {
                $state = New-TestState -View 'ParameterList'
                $state.Parameters       = @([pscustomobject]@{ Name = 'Path' })
                $state.CurrentParameter = $state.Parameters[0]
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.Parameters.Count  | Should -Be 0
                $state.CurrentParameter  | Should -BeNullOrEmpty
            }
        }

        # --- ParameterHelpContent view ---

        Context 'ParameterHelpContent view' {
            It 'Left arrow returns to ParameterList' {
                $state = New-TestState -View 'ParameterHelpContent'
                Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $state.View | Should -Be 'ParameterList'
            }
        }

        # --- Return values ---

        Context 'Return values' {
            It 'returns $true for normal navigation in Description view' {
                $state  = New-TestState
                $result = Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo DownArrow) -State $state
                $result | Should -Be $true
            }

            It 'returns $null when Left arrow with empty search is pressed in Description view' {
                $state  = New-TestState
                $result = Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo LeftArrow) -State $state
                $result | Should -BeNullOrEmpty
            }

            It 'returns $true for navigation in HelpOptions view' {
                $state  = New-TestState -View 'HelpOptions'
                $result = Invoke-ViewerInputHandler -KeyInfo (New-KeyInfo UpArrow) -State $state
                $result | Should -Be $true
            }
        }
    }
}
