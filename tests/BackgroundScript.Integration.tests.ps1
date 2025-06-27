$ScriptRoot = $PSScriptRoot
$ModulePath = ($ScriptRoot | Split-Path -Parent) + '\src'
$ProjectName = $ScriptRoot | Split-Path -Parent | Split-Path -Leaf
Import-Module "$ModulePath\$ProjectName.psm1" -Force
InModuleScope $ProjectName {
    Describe 'BackgroundScript' -Skip:(
        ([string]::IsNullOrEmpty($env:SN_TEST_INSTANCE)) -or
        ([string]::IsNullOrEmpty($env:SN_TEST_USERNAME)) -or
        ([string]::IsNullOrEmpty($env:SN_TEST_PASSWORD))
    ) {
        BeforeAll {
            . "$PSScriptRoot\Helpers\WebTestHelpers.ps1"
            Write-Host "Running BackgroundScript Integration tests against instance: $env:SN_TEST_INSTANCE"
            AssertTestSnowAuth -SetAuth
            
        }
        BeforeEach {
            $env:SNOW_MOCK_TAG = $null
        }          

        Context 'Invoke-SNOWBackgroundScript' -Tag 'Integration' {
            It 'should execute a background script successfully' {
                $TestGuid = [guid]::NewGuid().ToString()
                $ScriptContents = "gs.info('Executing PSSnow Test {0}')" -f $TestGuid
                $Response = Invoke-SNOWBackgroundScript -ScriptContents $ScriptContents -Scope 'global'
                $Response | Should -BeOfType 'PSCustomObject'
                $Response.ScriptResponse | Should -BeLike "*$TestGuid*"
            }

            It 'should execute a background script with a timeout' {
                $TestGuid = [guid]::NewGuid().ToString()
                $ScriptContents = "gs.info('Executing PSSnow Test {0}')" -f $TestGuid
                $Response = Invoke-SNOWBackgroundScript -ScriptContents $ScriptContents -Scope 'global'
                $Response | Should -BeOfType 'PSCustomObject'
                $Response.ScriptResponse | Should -BeLike "*$TestGuid*"
            }

            It 'should execute a background script successfully by fetching a new session.' {
                $Script:SNOWAuth.session = $null
                $Script:SNOWAuth.SessionState = $null
                $TestGuid = [guid]::NewGuid().ToString()
                $ScriptContents = "gs.info('Executing PSSnow Test {0}')" -f $TestGuid
                $Response = Invoke-SNOWBackgroundScript -ScriptContents $ScriptContents
                $Response | Should -BeOfType 'PSCustomObject'
                $Response.ScriptResponse | Should -BeLike "*$TestGuid*"
            }

            It 'should execute a background script in a specific scope' {
                $TestGuid = [guid]::NewGuid().ToString()
                $ScriptContents = "gs.info('Executing PSSnow Test {0}')" -f $TestGuid
                $Ctx = Get-SNOWBackgroundScriptContext
                $Scope = $Ctx.Scopes | Where-Object { -not $_.IsSelected } | Select-Object -Last 1
                if ($Scope) {
                    $Response = Invoke-SNOWBackgroundScript -ScriptContents $ScriptContents -Scope $Scope.Value
                    $Response | Should -BeOfType 'PSCustomObject'
                    $Response.ScriptResponse | Should -BeLike "*$TestGuid*"
                    $Response.ScriptResponse
                } else {
                    Write-Warning "No valid scope found for background script execution."
                }
            }
        }
    }
                    
}