function Start-SNOWGlideAjaxUpdateSetPreview {
    <#
    .SYNOPSIS
        Starts a preview of an update set in ServiceNow.

    .DESCRIPTION
        This function uses GlideAjax to start a preview of an update set in ServiceNow.
        It uses the UpdateSetPreviewAjax processor for single update sets and HierarchyUpdateSetPreviewAjax for batch update sets.
    
    .PARAMETER sys_id
        The sys_id of the remote update set to be previewed.

    .OUTPUTS
        Returns the raw GlideAjax response from the ServiceNow instance. 
    #>
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('remote_update_set_id')]
        [string]$sys_id
    )
    $UpdateSet = Get-SNOWUpdateSet -sys_id $sys_id
    if (-not $UpdateSet) {
        Write-Error "No update set found with sys_id: $sys_id"
        return
    }
    $RequestParams = @{
        sysparm_processor               = 'UpdateSetPreviewAjax'
        sysparm_scope                   = 'global'
        sysparm_want_session_messages   = 'true'
        sysparm_ajax_processor_function = 'preview'
        sysparm_ajax_processor_sys_id   = $sys_id
        sysparm_name                    = 'start'
        'ni.nolog.x_referer'            = 'ignore'
        x_referer                       = "sys_remote_update_set.do?sys_id=$sys_id"
    }
    if ($UpdateSet.remote_base_update_set) {
        Write-Host "Update set $($UpdateSet.Name) is a batch update set. Using HierarchyUpdateSetPreviewAjax processor."
        $RequestParams['sysparm_processor'] = 'HierarchyUpdateSetPreviewAjax'
    }
    if ($PreviewAgain) {
        $RequestParams['sysparm_ajax_processor_function'] = 'previewAgain'
    }
    return (Invoke-SNOWGlideAjax -Params $RequestParams).Answer
}