function Get-SNOWBackgroundScriptContext {
    <#
    .SYNOPSIS
        Retrieves the context for executing background scripts in ServiceNow, including available scopes and security token.
    .DESCRIPTION
        This function retrieves the context required for executing background scripts in ServiceNow.
        It extracts available scopes and the security token from the HTML content of the sys.scripts.do page.
        
        The function uses the ServiceNow endpoint: sys.scripts.do
    .EXAMPLE
        $context = Get-SNOWBackgroundScriptContext
        # Retrieves the context for executing background scripts, including available scopes and security token.
    .NOTES
        This function requires a valid ServiceNow web session. Ensure you are authenticated before calling this function
    #>
    [CmdletBinding()]
    param ()
    $HtmlContent = Invoke-SNOWWebRequest -URI 'sys.scripts.do' -Method 'GET' -UseRestMethod
    
    $Context = [PSCustomObject]@{
        Scopes        = @()
        SecurityToken = $null
    }
    # Extract the select element content first
    if ($HtmlContent -match '<select name="sys_scope"[^>]*>(.*?)</select>') {
        $selectContent = $matches[1]
        
        # Then extract each option with its value and text
        $optionsRegex = '<option(?: selected)? value="([^"]+)">([^<]+)</option>'
        $selectContent | Select-String -Pattern $optionsRegex -AllMatches | 
        ForEach-Object { $_.Matches } | 
        ForEach-Object {
            $Context.Scopes += [PSCustomObject]@{
                Value      = $_.Groups[1].Value
                Text       = $_.Groups[2].Value
                IsSelected = $_.Value -match 'selected'
            }
        }
    }
    else {
        Write-Warning "Could not find scope select element in the HTML content"
    }

    #Check for token in <input name="sysparm_ck" type="hidden" value="...">
    if ($HtmlContent -match '<input name="sysparm_ck" type="hidden" value="([^"]+)"') {
        $Context.SecurityToken = $matches[1]
    }
    else {
        Write-Warning "Could not find sysparm_ck input element in the HTML content"
    }
    return $Context
}