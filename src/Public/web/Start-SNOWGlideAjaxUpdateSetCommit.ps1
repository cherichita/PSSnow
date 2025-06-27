function Start-SNOWGlideAjaxUpdateSetCommit {
    <#
    .SYNOPSIS
        Starts the commit process for a ServiceNow update set.

    .DESCRIPTION
        This function starts the commit process for a ServiceNow update set using the GlideAjax API and WebSessions.
        It uses the following sysparm_processors:
        - UpdateSetCommitAjaxProcessor for validating the update set before committing it.
        - com.glide.update.UpdateSetCommitAjaxProcessor for single update sets.
        - HierarchyUpdateSetCommitAjax for batch update sets.
        The function validates the update set before committing it and can handle data loss scenarios if specified.

    .PARAMETER sys_id
        The sys_id of the remote update set to be committed.

    .PARAMETER ForceCommit
        Switch that indicates whether to force commit the update set.
        Force commits the update set even if you haven't yet previewed it to check for conflicts.
        
        Default: Doesn't force commit the update set. You must preview the update set before proceeding with the commit.

    .EXAMPLE
        Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef"
        
        Starts the commit process for the specified update set and returns the result.
        
    .EXAMPLE
        Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef" | Wait-SNOWCICDProgress
        
        Starts the commit process and waits for it to complete by piping the result to Wait-SNOWCICDProgress.
        
    .EXAMPLE
        Get-SNOWUpdateSet -sys_id "1234567890abcdef" | Start-SNOWGlideAjaxUpdateSetCommit | Wait-SNOWCICDProgress
        
        Gets the update set, starts the commit process, and waits for it to complete.

    .EXAMPLE
        Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef" -ForceCommit
        
        Forces the commit process for the specified update set, bypassing validation checks.
    .EXAMPLE
        Start-SNOWGlideAjaxUpdateSetCommit -sys_id "1234567890abcdef" -AcceptDataLoss "Dictionary:sys_dictionary_sn_si_incident_u_impacted_user_s,Dictionary:sys_dictionary_sn_si_incident_u_no_of_mission_critical_assets"
        
        Starts the commit process for the specified update set and accepts data loss for the specified fields.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('remote_update_set_id')]
        [string]$sys_id,

        [Parameter()]
        [switch]$ForceCommit,

        [Parameter()]
        # Accepts data loss during commit Example: Dictionary:sys_dictionary_sn_si_incident_u_impacted_user_s,Dictionary:sys_dictionary_sn_si_incident_u_no_of_mission_critical_assets
        [string]$AcceptDataLoss
    )
    $UpdateSet = Get-SNOWUpdateSet -sys_id $sys_id
    if (-not $UpdateSet) {
        Write-Error "No update set found with sys_id: $sys_id"
        return
    }
    if (-not $UpdateSet.state -eq 'previewed') {
        Write-Error "Update set $($UpdateSet.Name) must be previewed before committing."
        return
    }
    $ValidateParams = @{
        sysparm_processor               = 'com.glide.update.UpdateSetCommitAjaxProcessor'
        sysparm_scope                   = 'global'
        sysparm_want_session_messages   = 'true'
        sysparm_type                    = 'validateCommitRemoteUpdateSet'
        sysparm_remote_updateset_sys_id = $sys_id
        'ni.nolog.x_referer'            = 'ignore'
        x_referer                       = "sys_remote_update_set.do?sys_id=$sys_id"
    }
    $ValidateResponse = Invoke-SNOWGlideAjax -Params $ValidateParams
    if ($Answer = $ValidateResponse.Answer.answer) {
        $AnswerParts = $Answer -split ';'
        if ($AnswerParts.Length -ne 3) {
            Write-Error "Invalid response from validate commit: $($Answer)"
            return
        }
        if ($AnswerParts[2] -ne 'NONE') {
            if ($AcceptDataLoss -eq $AnswerParts[2]) {
                Write-Host "Data loss accepted for update set $($SysId) - $($AnswerParts[2])"
            }
            else {
                Write-Error "Data loss detected in update set $($SysId) - $($AnswerParts[2]) - Please commit manually."
            }
        }
        Write-Host "Update set $($UpdateSet.Name) is valid for commit."
        $CommitParams = if ($UpdateSet.remote_base_update_set) {
            Write-Host "Update set $($UpdateSet.name) is a batch update set. Using HierarchyUpdateSetCommitAjax processor."
            @{
                sysparm_processor               = 'HierarchyUpdateSetCommitAjax'
                sysparm_scope                   = 'global'
                sysparm_want_session_messages   = 'true'
                sysparm_ajax_processor_function = 'commit'
                sysparm_ajax_processor_sys_id   = $sys_id
                'ni.nolog.x_referer'            = 'ignore'
                x_referer                       = "sys_remote_update_set.do?sys_id=$sys_id"
            }
        }
        else {
            Write-Host "Update set $($UpdateSet.name) is a single update set. Using UpdateSetCommitAjax processor."
            @{
                sysparm_processor               = 'com.glide.update.UpdateSetCommitAjaxProcessor'
                sysparm_scope                   = 'global'
                sysparm_want_session_messages   = 'true'
                sysparm_type                    = 'commitRemoteUpdateSet'
                sysparm_remote_updateset_sys_id = $sys_id
                'ni.nolog.x_referer'            = 'ignore'
                x_referer                       = "sys_remote_update_set.do?sys_id=$sys_id"
            }
        }
        $CommitResponse = Invoke-SNOWGlideAjax -Params $CommitParams
        if ($CommitAnswer = $CommitResponse.Answer.answer) {
            $CommitAnswerParts = $CommitAnswer -split ','
            if ($CommitAnswerParts.Length -lt 1) {
                Write-Error "Invalid response from commit: $($CommitAnswer)"
                return
            }
            return @{
                answer = $CommitAnswerParts[0]
            }
        }
        else {
            Write-Error "No answer received from commit request."
            return
        }
    }
    else {
        Write-Error "Failed to validate commit for update set $($UpdateSet.Name): $($ValidateResponse.Answer)"
        return
    }
}