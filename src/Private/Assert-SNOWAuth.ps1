function Assert-SNOWAuth() {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        # Expressed in seconds
        $OauthExpiryBuffer = 180
    )
    
    if($null -eq $script:SNOWAuth){
        Write-Error "Please set ServiceNow authentication with Set-SNOWAuth" -ErrorAction Stop
    }

    if($script:SNOWAuth.Type -eq "OAuth"){
        $CurrentTime = Get-Date
        $ExpiryTime = $script:SNOWAuth.Expires.AddSeconds(-$OauthExpiryBuffer)
        if($ExpiryTime -le $CurrentTime){
            $ProxyAuth = $script:SNOWAuth.ProxyAuth
            #? Get a new token
            $Body = @{
                client_id = $script:SNOWAuth.ClientID
            }
            if($Script:SNOWAuth.token.refresh_token){
                $Body += @{
                    grant_type="refresh_token"
                    refresh_token = $script:SNOWAuth.token.refresh_token
                }
            }elseif($Script:SNOWAuth.Credential){
                $Body += @{
                    grant_type="password"
                    username = $script:SNOWAuth.Credential.GetNetworkCredential().Username
                    password = $script:SNOWAuth.Credential.GetNetworkCredential().Password
                }
            }elseif($script:SNOWAuth.ClientSecret){
                $Body += @{
                    grant_type="client_credentials"
                }
            }else{
                Write-Error "No valid authentication method found to obtain OAuth token. One of Credential, Refresh Token, or Client Secret must be available." -ErrorAction Stop
            }
            # If client secret is provided, add it to the body. Public clients can refresh tokens without a client secret.
            if ($script:SNOWAuth.ClientSecret) {
                $Body.client_secret = [System.Net.NetworkCredential]::new('dummy', $script:SNOWAuth.ClientSecret).Password
            }
            Write-Verbose "Requesting new OAuth token from ServiceNow instance $($Script:SNOWAuth.Instance) grant_type: $($Body.grant_type)"
            $Token = Invoke-RestMethod -Method POST -uri "https://$($Script:SNOWAuth.Instance).service-now.com/oauth_token.do" -Body $Body -Verbose:$false @ProxyAuth

            $script:SNOWAuth.token = $token
            $script:SNOWAuth.Expires = (get-date).AddSeconds($Token.expires_in)
        }
    }
    if ($script:SNOWAuth.session) {
        Assert-SNOWAuthWebSession
    }
}

