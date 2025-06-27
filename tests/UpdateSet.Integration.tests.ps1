$ScriptRoot = $PSScriptRoot
$ModulePath = ($ScriptRoot | Split-Path -Parent) + '\src'
$ProjectName = $ScriptRoot | Split-Path -Parent | Split-Path -Leaf
Import-Module "$ModulePath\$ProjectName.psm1" -Force

InModuleScope $ProjectName {
    BeforeAll {
        . "$PSScriptRoot\Helpers\WebTestHelpers.ps1"
        AssertTestSNOWAuth -SetAuth
        function Test-SNOWApiExists {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Uri
            )
            $ApiEndpoint = $Uri -replace '^https?://[^/]+', '' -replace '^/api', '' -replace '^/',''
            $ApiParts = $ApiEndpoint -split '/'
            if ($ApiParts.Count -lt 1) {
                throw "Invalid API endpoint: $Uri"
            }
            $Namespace = $ApiParts[0]
            if($ApiParts.Count -gt 1) {
                $Route = $ApiParts[0..1] -join '/'
            }
            $RestDocs = Invoke-SNOWWebRequest -URI "/api/now/doc/services?namespace=${Namespace}" -UseRestMethod
            if($RestDocs.result){
                $ApiProps = $RestDocs.result."${Namespace}".PSObject.Properties.Value | Where-Object { $_.route -eq $Route }
                if ($ApiProps) {
                    return $ApiProps
                } else {
                    throw "API endpoint not found: $Uri"
                }
            }
            $ApiEndpoint
        }
    }

    Describe Test-SNOWApiExists -Tag 'Unit' {
        It 'Should return the correct API endpoint for a valid URI' {
            $uri = 'https://example.service-now.com/api/sn_cicd/instance_scan'
            $result = Test-SNOWApiExists -Uri $uri
            $result | Should -Not -BeNullOrEmpty
            $result.route | Should -Be 'sn_cicd/instance_scan'
            $result.svcName | Should -Be 'CICD Instance Scan Execution Service'
        }

        It 'Should throw an error for an invalid URI' {
            { Test-SNOWApiExists -Uri 'https://example.service-now.com/api/invalid/endpoint' } | Should -Throw "API endpoint not found: https://example.service-now.com/api/invalid/endpoint"
        }
    }
    Describe 'UpdateSet Integration Tests' -Skip:(
        ([string]::IsNullOrEmpty($env:SN_TEST_INSTANCE)) -or
        ([string]::IsNullOrEmpty($env:SN_TEST_USERNAME)) -or
        ([string]::IsNullOrEmpty($env:SN_TEST_PASSWORD))
    ) -Tag 'Integration' {
        BeforeAll {
            # Define paths for test files
            $SampleUpdateSetPath = "$PSScriptRoot\TestFiles\sample_update_set.xml"
            $SampleUpdateSetPath2 = "$PSScriptRoot\TestFiles\sample_update_set_2.xml"
            $TestUpdateSetName = "Test Import Set"
            
            # Store created resources for cleanup
            $script:CreatedResources = @{
                UpdateSets = @()
            }
            Write-Host "Running PSSnow UpdateSet tests. Instance: $env:SN_TEST_INSTANCE"
        }
        
        
        
        Context 'Search-SNOWUpdateSet' -Tag 'Integration' {
            It 'Should retrieve update sets with no parameters' {
                $updateSets = Search-SNOWUpdateSet
                $updateSets | Should -Not -BeNullOrEmpty
                $updateSets.sys_update_set.Count | Should -BeGreaterThan 0
                $updateSets.sys_update_set[0].name | Should -Not -BeNullOrEmpty
                $updateSets.sys_update_set[0].sys_id | Should -Not -BeNullOrEmpty
            }
            It 'Should retrieve update sets with a specific name' {
                $env:SNOW_MOCK_TAG = 'SearchNoResults'
                $updateSets = Search-SNOWUpdateSet -Query "name=$TestUpdateSetName"
                $updateSets | Should -Not -BeNullOrEmpty
                $env:SNOW_MOCK_TAG = $null
            }
        }

        
        
        
        Context 'Import-SNOWUpdateSet' -Tag 'Integration' {
            BeforeAll {
                $script:ImportedUpdateSetSysId = $null
                $env:SNOW_MOCK_TAG = $null
            }
            AfterAll {
                # Clean up any test update sets
                foreach ($updateSetId in $script:CreatedResources.UpdateSets) {
                    try {
                        $null = Invoke-SNOWWebRequest -URI "api/now/table/sys_remote_update_set/$updateSetId" -Method DELETE -UseRestMethod
                    }
                    catch {
                        Write-Warning "Failed to clean up test update set: $updateSetId"
                    }
                }
                
                # Clean up any exported files
                foreach ($filePath in $script:CreatedResources.ExportedFiles) {
                    if (Test-Path $filePath) {
                        Remove-Item -Path $filePath -Force
                    }
                }
            }
            It 'Should import an update set from an XML file' {
                $env:SKIP_MOCKS = $null
                $env:SNOW_MOCK_TAG = 'ImportUpdateSet'
                $importResult = Import-SNOWUpdateSet -Path $SampleUpdateSetPath
                $script:ImportedUpdateSetSysId = $importResult.sys_id
                $script:CreatedResources.UpdateSets += $script:ImportedUpdateSetSysId
                $env:SNOW_MOCK_TAG = $null
                $env:SKIP_MOCKS = 'true'
                $importResult | Should -Not -BeNullOrEmpty
                $importResult.sys_id | Should -Not -BeNullOrEmpty
                $importResult.PSObject.Properties.Name | Should -Contain 'name'
                $env:SNOW_MOCK_TAG = 'SearchOneResult'
                $updateSets = Search-SNOWUpdateSet -Query "name=$TestUpdateSetName"
                $updateSets.sys_remote_update_set | Should -Not -BeNullOrEmpty
                # Store for cleanup
                $env:SNOW_MOCK_TAG = $null
            }
            
            It 'Should throw an error for invalid XML' {
                # Create an invalid XML file
                $invalidXmlPath = Join-Path -Path $TestDrive -ChildPath "invalid.xml"
                Set-Content -Path $invalidXmlPath -Value "<invalid>not a valid update set XML</invalid>"
                
                { Import-SNOWUpdateSet -Path $invalidXmlPath -ErrorAction Stop } | Should -Throw
            }
        }
        
        Context 'Full Preview and Commit' -Tag 'Integration' {
            BeforeEach {
                $LocalUpdateSets = Get-SNOWObject -Table 'sys_update_set' -Query "name=$TestUpdateSetName^state=complete"
                if ($LocalUpdateSets) {
                    foreach ($updateSet in $LocalUpdateSets) {
                        try {
                            Write-Host "Cleaning up existing test update set: $($updateSet.sys_id)"
                            $BackoutScript = @"
                            var gr = new GlideRecord('sys_update_set');
                            if(gr.get('$($updateSet.sys_id)')){
                                gs.info('Deleting update set: $($updateSet.sys_id)');
                                gr.deleteRecord();
                            }
"@
                            Invoke-SNOWBackgroundScript -ScriptContents $BackoutScript -Scope 'global'
                        }
                        catch {
                            Write-Warning "Failed to clean up test update set: $($updateSet.sys_id)"
                            Write-Warning $_
                        }
                    }
                }

                # Create an update set to modify
                $importResult = Import-SNOWUpdateSet -Path $SampleUpdateSetPath
                
                $importResult | Should -Not -BeNullOrEmpty
                $importResult.sys_id | Should -Not -BeNullOrEmpty
                $importResult.PSObject.Properties.Name | Should -Contain 'name'
                # Store for cleanup
                $script:ImportedUpdateSetSysId = $importResult.sys_id
                $script:CreatedResources.UpdateSets += $script:ImportedUpdateSetSysId
                function Resolve-SNOWPreviewProblem {
                    param(
                        [string]$sys_id,
                        [ValidateSet('skipUpdate', 'ignoreProblem')]
                        [string]$ErrorAction = 'skipUpdate'
                    )
                    if ($ErrorAction) {
                        $ScriptContents = @"
    var gr = new GlideRecord('sys_update_preview_problem');
    gr.get('$($sys_id)');
    var ppaIgn = new GlidePreviewProblemAction(new GlideAction(), gr);
    ppaIgn.$($ErrorAction)();
"@
                        $Response = Invoke-SNOWBackgroundScript -ScriptContents $ScriptContents -Scope 'global'
                        if ($Response.ScriptResponse) {
                            return $Response.ScriptResponse
                        }
                    }
                }
            }
            AfterEach {
                #Clean up any test update sets
                foreach ($updateSetId in $script:CreatedResources.UpdateSets) {
                    try {
                        Remove-SNOWUpdateSet -sys_id $updateSetId -sys_class_name 'sys_remote_update_set' -Confirm:$false
                    }
                    catch {
                        Write-Warning "Failed to clean up test update set: $updateSetId"
                        Write-Warning $_
                    }
                }
                $script:CreatedResources.UpdateSets.Clear()
            }
            
            It 'Should preview and commit using Start-SNOWGlideAjaxUpdateSetPreview and Start-SNOWGlideAjaxUpdateSetCommit' {
                $env:SNOW_MOCK_TAG = 'PreviewUpdateSet'
                $previewResult = Start-SNOWGlideAjaxUpdateSetPreview -sys_id $script:ImportedUpdateSetSysId | Wait-SNOWGlideAjaxProgress
                $previewResult | Should -Not -BeNullOrEmpty
                $previewResult.state | Should -BeGreaterThan 1
                if ($previewResult.state -gt 2) {
                    # Failed - Check for errors
                    $Query = "^status=^remote_update_set.remote_base_update_set=$ImportedUpdateSetSysId^ORremote_update_set=$ImportedUpdateSetSysId"
                    $previewProblems = Get-SNOWObject -Table 'sys_update_preview_problem' -Query $Query
                    foreach ($problem in $previewProblems) {
                        Resolve-SNOWPreviewProblem -sys_id $problem.sys_id -ErrorAction 'skipUpdate' | Out-Null
                    }
                }
                $CommitResult = Start-SNOWGlideAjaxUpdateSetCommit -sys_id $script:ImportedUpdateSetSysId  | Wait-SNOWGlideAjaxProgress
                $CommitResult.state | Should -BeGreaterThan 1
                $CommitResult.percent_complete | Should -Be 100
            }

            It 'Should preview and commit using Start-SNOWUpdateSetPreview and Start-SNOWUpdateSetCommit (sn_cicd API)' {
                $env:SNOW_MOCK_TAG = 'PreviewUpdateSet'
                $previewResult = Start-SNOWUpdateSetPreview -sys_id $script:ImportedUpdateSetSysId | Wait-SNOWCICDProgress -ErrorAction SilentlyContinue
                $previewResult | Should -Not -BeNullOrEmpty
                $previewResult.remote_update_set_id | Should -Not -BeNullOrEmpty
                if ($previewResult.status -gt 2) {
                    # Failed - Check for errors
                    $Query = "^status=^remote_update_set.remote_base_update_set=$ImportedUpdateSetSysId^ORremote_update_set=$ImportedUpdateSetSysId"
                    $previewProblems = Get-SNOWObject -Table 'sys_update_preview_problem' -Query $Query
                    foreach ($problem in $previewProblems) {
                        Write-Host "Resolving problem: $($problem.sys_id) with action: ignoreProblem"
                        Resolve-SNOWPreviewProblem -sys_id $problem.sys_id -ErrorAction 'ignoreProblem' | Out-Null
                    }
                }
                $commitResult = Start-SNOWUpdateSetCommit -sys_id $script:ImportedUpdateSetSysId | Wait-SNOWCICDProgress
                $commitResult | Should -Not -BeNullOrEmpty
                # Since we're just getting the raw result now, not the wrapped object with UpdateSet property
                $commitResult.local_update_set_id | Should -Not -BeNullOrEmpty
                $commitResult.percent_complete | Should -Be 100
            }
        }
    }
}