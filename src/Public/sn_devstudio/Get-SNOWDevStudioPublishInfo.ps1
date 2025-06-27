function Get-SNOWDevStudioPublishInfo {
    <#
        .SYNOPSIS
            Gets publish info (including cK token) from sn_devstudio_/v1/get_publish_info endpoint.
        .DESCRIPTION
            This function retrieves the publish information from the ServiceNow instance using the sn_devstudio_/v1/get_publish_info endpoint.
            It returns the cK token and other relevant information needed for publishing updates.
        .OUTPUTS
            Returns a PowerShell object containing the publish information, including the cK token.
        .EXAMPLE
            Get-SNOWDevStudioPublishInfo
                all_scopes                : 
                allowCustomizationUpload  : True
                allowInternalUpload       : True
                allowStoreUpload          : False
                appCustomizationVersion   : 1.0.0
                canPublishToRepo          : False
                canPublishToStore         : False
                ck                        : f3b53b4ffb1eaa109b12f6d87befdca00f1fac998394cf783e42f82e54e8236a2640b047
                companyKey                : mogs2
                companyName               : omgcsdev
                dependencyWarningMsg      : The application identifier is invalid
                dirty_sc_scopes           : 
                isAppCustomizationCapable : False
                isJumbo                   : False
                targetUrl                 : {https://apprepo.service-now.com/}
        .NOTES
            After Yokohama, the cK token obtained from this endpoint cannot be used to invoke background scripts
            unless the session is using oauth tokens. This is not documented anywhere. 
            This function is provided as-is and may not work in all instances or versions of ServiceNow.
        .OUTPUTS
            Returns a PowerShell object containing the publish information, including the cK token.
                
    #>
    $PublishRequest = @{
        Uri    = "sn_devstudio_/v1/get_publish_info"
        Method = 'GET'
    }
    
    $PublishResponse = $null
    try {
        $Script:PSDefaultParameterValues['Invoke-WebRequest:MaximumRedirection'] = 0
        $PublishResponse = Invoke-SNOWWebRequest @PublishRequest
    }
    catch { 
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Warning "Authentication failed. Please check your credentials."
        }
        elseif ($_.Exception.Response.StatusCode -eq 302) {
            Write-Warning "302 response received. API Endpoint may be missing @ $($PublishRequest.Uri)"
        }
        $PublishResponse = $_.Exception.Response
    }
    finally {
        $Script:PSDefaultParameterValues['Invoke-WebRequest:MaximumRedirection'] = 5
    }
    $PublishResponseObject = try { $PublishResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue } catch { 
        Write-Warning "Failed to parse JSON response from $($PublishRequest.Uri) $($_.Exception.Message)"
        $null
    }
    return $PublishResponseObject
}