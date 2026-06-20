# Set up localization
$TextModulePath = Join-Path -Path $psScriptRoot -ChildPath "\SConfig.Text.psm1"
Import-Module -Name $TextModulePath -Force
$StringTable = Get-SCfLocalizedStringTable
$SingleCharLookup = Get-SCfSingleCharLookupTable $StringTable
$StringTable = Convert-SCfAmpersandToParentheses $StringTable # Converts single-char identifier "&" to a set of parentheses around the letter

# Dependencies on Set-SCfComputerName and Invoke-SCfRestartPrompt
Import-Module -Name "$psScriptRoot\SConfig.Computer.psm1" -Force

<#
    Guides the user through joining a new domain or workgroup: returns true if setting was changed
    Inputs:
        CurrentSetting: current workgroup or Domain
        CurrentLabel: 'workgroup' or 'domain', LocalizedStrings
        InDomain: boolean indicating whether or not the computer is domain-joined
        Output: boolean indicating whether or not a new domain/workgroup was joined
#>
function Set-SCfDomainWorkGroup
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $CurrentSetting,

        [Parameter(Mandatory=$true)]
        $CurrentLabel,

        [Parameter(Mandatory=$true)]
        $InDomain
    )

    Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.DomainWorkgroup_Title)
  $($StringTable.DomainWorkgroup_Current) $($CurrentLabel.toLower())$($CurrentSetting)

"@

    $InputList = $SingleCharLookup['DomainWorkgroup_Prompt']
    do { $UserInput = Read-SCfHost -Prompt @($StringTable.DomainWorkgroup_Prompt, $StringTable.BlankToCancel) }
    until ($InputList -contains $UserInput)
    if (-not $UserInput) { return $false }

    # User selects join workgroup
    if ($UserInput -eq $InputList[0])
    { # 'Domain'
        return Set-SCfDomain -WhatIf:$WhatIfPreference
    }
    elseif ($UserInput -eq $InputList[1]) # 'Workgroup'
    {
        $Parameters = @{
            InDomain = $InDomain
            WhatIf   = $WhatIfPreference
        }

        return Set-SCfWorkgroup @Parameters
    }
}

<#
    Set the domain based on user input
    Input: InDomain, whether or not the use is already in a domain
    Output: boolean indicating whether or not new domain was joined successfully
#>
function Set-SCfDomain
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param()

    # Enter desired domain
    $Domain = Read-SCfHost -Prompt @($StringTable.DomainWorkgroup_DomainPrompt, $StringTable.BlankToCancel)
    if (-not $Domain) { return $false }

    # Enter authorized user
    $Username = Read-SCfHost -Prompt @($StringTable.AuthorizedPrompt, $StringTable.BlankToCancel)
    if (-not $Username) { return $false }
    $Password = Read-SCfHost -Prompt $($StringTable.AuthorizedPasswordPrompt -f $Username) -AsSecureString

    $Parameters = @{
        TypeName     = 'System.Management.Automation.PSCredential';
        ArgumentList = ([String]$Username, [System.Security.SecureString]$Password)
    }
    $Credential = New-Object @Parameters

    # Progress note
    Write-SCfHost -Object $($StringTable.DomainWorkgroup_Joining -f $Domain)

    # Join domain
    try
    {
        if ($PSCmdlet.ShouldProcess($Domain, 'Add-Computer'))
        {
            Add-Computer -DomainName $Domain -Credential $Credential -Force
        }

        Write-SCfHost -Object $StringTable.DomainWorkgroup_JoinedDomain

        $Rename = Read-SCfHost -Prompt @($StringTable.DomainWorkgroup_RenameComputerPrompt, $StringTable.YesNoSuffix)
        if ($Rename -eq $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
        {
            $Parameters = @{
                CurrentSetting = [String]::Empty
                InDomain       = $true
                Inline         = $true
                Username       = $Username
                WhatIf         = $WhatIfPreference
            }

            Set-SCfComputerName @Parameters
        }
        else
        {
            Invoke-SCfRestartPrompt
        }

        return $true
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.DomainWorkgroup_Domain_Failed
        return $false
    }
}

<#
    Set the workgroup based on user input
    Inputs:
    CurrentSetting: current domain/workgroup, in case it needs to be rejoined
    InDomain: boolean, indicating whether or not the user is already in a Domain
    Output: boolean indicating whether or not the workgroup was joined successfully
#>
function Set-SCfWorkgroup
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $InDomain
    )

    Write-SCfHost -Indent 0 -Object @"

  $($StringTable.DomainWorkgroup_WorkgroupRules1)
  $($StringTable.DomainWorkgroup_WorkgroupRules2)
  ~ ` @ # $ % ^ ( ) { } [ ] | + = * : ; , . < > ?

"@

    <#
        Enter desired workgroup, tests the workgroup name for the following rules:
        - No more than 15 characters
        - Cannot contain any of the following special characters: ~ ` @ # $ % ^ ( ) { } [ ] | + = * : ; , . < > ?
    #>
    do { $Workgroup = Read-SCfHost -Prompt @($StringTable.DomainWorkgroup_WorkgroupPrompt, $StringTable.BlankToCancel) }
    until (-not $Workgroup -or $($Workgroup.length -lt 15 -and $Workgroup -match '^[^~`@#\$%\^/\(\)\{\}\[\]\|\+\=\*:;,\.<>\?\s]+$'))
    if (-not $Workgroup) { return $false }

    # If already in a domain
    if ($InDomain)
    {
        # Query removal from domain
        Write-SCfHost -Object $StringTable.DomainWorkgroup_CurrentlyJoined
        $UserInput = Read-SCfHost -Prompt @($StringTable.DomainWorkgroup_RemovePrompt, $StringTable.YesNoSuffix)

        # User confirm they want to remove machine from old domain
        if ($UserInput -ne $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
        {
            Write-SCfHost -Object $StringTable.Canceling
            return $false
        }

        # Enter authorized user
        $Username = Read-SCfHost -Prompt @($StringTable.AuthorizedPrompt, $StringTable.BlankToCancel)
        if (-not $Username) { return $false }
        $Password = Read-SCfHost -Prompt $($StringTable.AuthorizedPasswordPrompt -f $Username) -AsSecureString

        $Parameters = @{
            TypeName     = 'System.Management.Automation.PSCredential'
            ArgumentList = ([String]$Username, [System.Security.SecureString]$Password)
        }
        $Credential = New-Object @Parameters

        try
        {
            # Leave domain and join workgroup
            Write-SCfHost -Object $StringTable.DomainWorkgroup_RemovingComputer
            Write-SCfHost -Object $($StringTable.DomainWorkgroup_Joining -f $Workgroup)

            if ($PSCmdlet.ShouldProcess($Workgroup, 'Remove-Computer'))
            {
                Remove-Computer -UnjoinDomainCredential $Credential -WorkgroupName $Workgroup -Force
            }

            Write-SCfHost -Object $StringTable.DomainWorkgroup_JoinedWorkgroup
            Invoke-SCfRestartPrompt
        }
        catch
        {
            Invoke-SCfErrorHandler -Error $_ -Message $StringTable.DomainWorkgroup_Workgroup_Failed
            return $false
        }
    }
    else
    {
        # Join workgroup
        try
        {
            Write-SCfHost -Object $($StringTable.DomainWorkgroup_Joining -f $Workgroup)
            if ($PSCmdlet.ShouldProcess($Workgroup, 'Add-Computer'))
            {
                Add-Computer -WorkgroupName $Workgroup -Force
            }

            Write-SCfHost -Object $StringTable.DomainWorkgroup_JoinedWorkgroup
            Invoke-SCfRestartPrompt
        }
        catch
        {
            Invoke-SCfErrorHandler -Error $_ -Message $StringTable.DomainWorkgroup_Workgroup_Failed
        }
    }
}

# Configure network adapter setting based on user input
function Set-SCfNetworkSetting
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$false)]
        [Switch]
        $DebugOutput
    )

    try
    {
        $Adapters = Get-CimInstance -Query 'select * from Win32_NetworkAdapterConfiguration where IPEnabled=true'
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.NetworkSettings_Failed
        return $false
    }

    $IndexPaddingParameters = @{
        Label           = $StringTable.NetworkSettings_ColumnHeader_Index
        Value           = [System.String]::Empty
        MaxValueLength  = 4
        GetLabelPadding = $true
    }
    $IndexPadding = Get-SCfColumnValuePadding @IndexPaddingParameters

    $IpPaddingParameters = @{
        Label           = $StringTable.NetworkSettings_ColumnHeader_IpAddress
        Value           = [System.String]::Empty
        MaxValueLength  = 16
        GetLabelPadding = $true
    }
    $IpPadding = Get-SCfColumnValuePadding @IpPaddingParameters

    Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.NetworkSettings_Title)
  $($StringTable.NetworkSettings_Available)

  $($StringTable.NetworkSettings_ColumnHeader_Index)$IndexPadding| $($StringTable.NetworkSettings_ColumnHeader_IpAddress)$IpPadding| $($StringTable.NetworkSettings_ColumnHeader_Description)
"@

    try
    {
        foreach ($Adapter in $Adapters)
        {
            $IndexPaddingParameters = @{
                Label          = $StringTable.NetworkSettings_ColumnHeader_Index
                Value          = $Adapter.Index
                MaxValueLength = 4
            }
            $IndexPadding = Get-SCfColumnValuePadding @IndexPaddingParameters

            $IpPaddingParameters = @{
                Label          = $StringTable.NetworkSettings_ColumnHeader_IpAddress
                Value          = $Adapter.IPAddress[0]
                MaxValueLength = 16
            }
            $IpPadding = Get-SCfColumnValuePadding @IpPaddingParameters

            Write-SCfHost -Object "$($Adapter.Index)$IndexPadding| $($Adapter.IPAddress[0])$IpPadding| $($Adapter.Description)"
        }
    }
    catch [System.ArgumentOutOfRangeException]
    {
        if (-not $DebugOutput.IsPresent) { Clear-Host }
        Write-SCfHost -Indent 0 -Object $(Get-SCfHeader $StringTable.NetworkSettings_Title)
        Write-SCfHost -Object $StringTable.NetworkSettings_TimingRetry
        Read-SCfHost -Prompt $StringTable.Continue
        return $false
    }

    # Trailing newline
    Write-SCfHost -Indent 0

    $Indices = @([String]::Empty)
    foreach ($Adapter in $Adapters)
    {
        $Indices += $Adapter.Index
    }

    do { $Index = Read-SCfHost -Prompt @($StringTable.NetworkSettings_IndexPrompt, $StringTable.BlankToCancel) }
    until ($Indices -contains $Index)
    if (-not $Index) { return $false }

    if (-not $DebugOutput.IsPresent) { Clear-Host }
    Set-SCfNetworkAdapter $Index -WhatIf:$WhatIfPreference
}

# Configure specific network adapter based on index (NetworkSelection)
function Set-SCfNetworkAdapter
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $Index
    )

    try
    {
        Write-SCfHost -Indent 0 -Object $(Get-SCfHeader $StringTable.NetworkSettings_AdapterSettings)
        $NetworkAdapter = Get-CimInstance -Query "select * from Win32_NetworkAdapterConfiguration where IPEnabled=true and Index=$Index"
        if ($NetworkAdapter.DNSServerSearchOrder.length -gt 0) { $PrimaryDNS = $NetworkAdapter.DNSServerSearchOrder[0] }
        if ($NetworkAdapter.DNSServerSearchOrder.length -eq 2) { $AltDNS = $NetworkAdapter.DNSServerSearchOrder[1] }

        $Labels = @(
            $StringTable.NetworkSettings_NicIndex,
            $StringTable.NetworkSettings_Description,
            $StringTable.NetworkSettings_IpAddress,
            $StringTable.NetworkSettings_SubnetMask,
            $StringTable.NetworkSettings_DhcpEnabled
        )
        $Padding = Get-SCfLabelPaddingArray $Labels

        # Wrap IPAddress value
        if ($NetworkAdapter.IPAddress.length -gt 1)
        {
            $LeadingSpaces = $StringTable.NetworkSettings_IpAddress.length + $Padding[$StringTable.NetworkSettings_IpAddress].length
            $IpAddressString = $NetworkAdapter.IPAddress[0]
            for ($i = 1; $i -lt $NetworkAdapter.IPAddress.length; $i++)
            {
                $IpAddressString += ",`n  " + (' ' * $LeadingSpaces) + $NetworkAdapter.IPAddress[$i]
            }
        }
        else
        {
            $IpAddressString = $NetworkAdapter.IPAddress
        }

        $LabelGroup1 =  @"
  $($StringTable.NetworkSettings_NicIndex)$($Padding[$StringTable.NetworkSettings_NicIndex])$Index
  $($StringTable.NetworkSettings_Description)$($Padding[$StringTable.NetworkSettings_Description])$($NetworkAdapter.Description)
  $($StringTable.NetworkSettings_IpAddress)$($Padding[$StringTable.NetworkSettings_IpAddress])$IpAddressString
  $($StringTable.NetworkSettings_SubnetMask)$($Padding[$StringTable.NetworkSettings_SubnetMask])$($NetworkAdapter.IPSubnet[0])
  $($StringTable.NetworkSettings_DhcpEnabled)$($Padding[$StringTable.NetworkSettings_DhcpEnabled])$($NetworkAdapter.DHCPenabled)
"@
        $Labels = @(
            $StringTable.NetworkSettings_DefaultGateway,
            $StringTable.NetworkSettings_PreferredDNS,
            $StringTable.NetworkSettings_AlternateDNS
        )
        $Padding = Get-SCfLabelPaddingArray $Labels

        $LabelGroup2 = @"
  $($StringTable.NetworkSettings_DefaultGateway)$($Padding[$StringTable.NetworkSettings_DefaultGateway])$($NetworkAdapter.DefaultIPGateway)
  $($StringTable.NetworkSettings_PreferredDNS)$($Padding[$StringTable.NetworkSettings_PreferredDNS])$PrimaryDNS
  $($StringTable.NetworkSettings_AlternateDNS)$($Padding[$StringTable.NetworkSettings_AlternateDNS])$AltDNS
"@

        $MenuOptions = @"
    1) $($StringTable.NetworkSettings_MenuOptions_SetAdapter)
    2) $($StringTable.NetworkSettings_MenuOptions_SetDNS)
    3) $($StringTable.NetworkSettings_MenuOptions_ClearDNS)
"@

        Write-SCfHost -Indent 0 -Object @"
$LabelGroup1

$LabelGroup2

$MenuOptions

"@

        $InputList = @('1', '2', '3', [String]::Empty)
        do { $NIC_option = Read-SCfHost -Prompt @($StringTable.SelectionPrompt, $StringTable.BlankToCancel) }
        until ($InputList -contains $NIC_option)

        $Parameters = @{
            NetworkAdapter = $NetworkAdapter
            WhatIf         = $WhatIfPreference
        }

        switch ($NIC_option)
        {
            '1' { Set-SCfAdapterAddress @Parameters }
            '2' { Set-SCfDNSServerSearchOrder @Parameters }
            '3' { Reset-SCfDNSServerSearchOrder @Parameters }
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.NetworkSettings_Failed
    }
}

<#
    Set IP address for adapter
    Input: Network Adapter CIM instance
#>
function Set-SCfAdapterAddress
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $NetworkAdapter
    )

    $InputList = $SingleCharLookup['NetworkSettings_Adapter_IpPrompt']
    do { $Selection = Read-SCfHost -Prompt @($StringTable.NetworkSettings_Adapter_IpPrompt, $StringTable.BlankToCancel) }
    until ($InputList -contains $Selection)

    $Parameters = @{
        NetworkAdapter = $NetworkAdapter
        WhatIf         = $WhatIfPreference
    }

    if ($Selection -eq $InputList[0]) # 'DHCP'
    {
        Set-SCfDHCPAddress @Parameters
    }
    elseif ($Selection -eq $InputList[1]) # 'Static'
    {
        Set-SCfStaticIpAddress @Parameters
    }
}

<#
    Set static IP address for adapter
    Input: Network Adapter CIM instance
#>
function Set-SCfStaticIpAddress
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $NetworkAdapter
    )

    $ipRegEx = '\A(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\z'

    do { $IpAddress = Read-SCfHost -Prompt @($StringTable.NetworkSettings_Adapter_StaticIpPrompt, $StringTable.BlankToCancel) }
    while (-not $IpAddress -or $IpAddress -notmatch $ipRegEx)
    if (-not $IpAddress) { return $false }

    if ($IpAddress -match '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b')
    {
        $DefaultMask = '255.255.255.0'
        $NetMask = Read-SCfHost -Prompt $($StringTable.NetworkSettings_Adapter_MaskPrompt -f $DefaultMask)
        if (-not $NetMask) { $NetMask = $DefaultMask }

        do {
            $Gateway = Read-SCfHost -Prompt @($StringTable.NetworkSettings_Adapter_DefaultPrompt, $StringTable.BlankToCancel)
            if (-not $Gateway) { return $false }
            $GatewayArr = $Gateway.Split('.')
        }
        until ($GatewayArr[0] -gt 0 -and $GatewayArr[0] -lt 224)
    }
    else
    {
        # IPv6
    }

    Write-SCfHost -Object $StringTable.NetworkSettings_Adapter_SettingStatic
    $RebootRequired = $false

    try
    {
        $ResultCode = $null

        # ReleaseDHCPLease
        if ($PSCmdlet.ShouldProcess($NetworkAdapter, 'Invoke-CimMethod:ReleaseDHCPLease')) {
            $ResultCode = $(Invoke-CimMethod -InputObject $NetworkAdapter -MethodName ReleaseDHCPLease).ReturnValue
        }

        if ($ResultCode -eq 1) { $RebootRequired = $true }
        $Failed = Write-SCfResultText $ResultCode 'ReleaseDHCPLease' $StringTable.NetworkSettings_ReleaseDHCPLease_Succeeded $StringTable.NetworkSettings_ReleaseDHCPLease_Failed
        if ($Failed) { return $false }

        # EnableStatic
        $IpAddressArg = [System.Collections.Generic.List[String]]@($IpAddress)
        $SubnetMaskArg = [System.Collections.Generic.List[String]]@($NetMask)
        if ($PSCmdlet.ShouldProcess(@($NetworkAdapter, $IpAddress, $NetMask), 'Invoke-CimMethod:EnableStatic'))
        {
            $Parameters = @{
                InputObject = $NetworkAdapter
                MethodName  = 'EnableStatic'
                Arguments   = @{
                    IPAddress  = $IpAddressArg
                    SubnetMask = $SubnetMaskArg
                }
            }
            $ResultCode = (Invoke-CimMethod @Parameters).ReturnValue
        }

        if ($ResultCode -eq 1) { $RebootRequired = $true }
        $Failed = Write-SCfResultText $ResultCode 'EnableStatic' $StringTable.NetworkSettings_EnableStatic_Succeeded $StringTable.NetworkSettings_EnableStatic_Failed
        if ($Failed) { return $false }

        # SetGateways
        $DefaultIPGatewayArg = [System.Collections.Generic.List[String]]@($Gateway)
        if ($PSCmdlet.ShouldProcess(@($NetworkAdapter, $Gateway), 'Invoke-CimMethod:SetGateways'))
        {
            $Parameters = @{
                InputObject = $NetworkAdapter
                MethodName  = 'SetGateways'
                Arguments   = @{
                    DefaultIPGateway = $DefaultIPGatewayArg
                }
            }
            $ResultCode = (Invoke-CimMethod @Parameters).ReturnValue
        }

        if ($ResultCode -eq 1) { $RebootRequired = $true }
        $Failed = Write-SCfResultText $ResultCode 'SetGateways' $StringTable.NetworkSettings_SetGateways_Succeeded $StringTable.NetworkSettings_SetGateways_Failed
        if ($Failed) { return $false }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.NetworkSettings_Adapter_Failed
    }

    if ($RebootRequired)
    {
        Invoke-SCfRestartPrompt
    }
    else
    {
        Write-SCfHost -Object $StringTable.NetworkSettings_Adapter_Success
        Read-SCfHost -Prompt $StringTable.Continue
    }

    return $true
}

<#
    Set DHCP for adapter
    Input: Network Adapter CIM instance
#>
function Set-SCfDHCPAddress
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        $NetworkAdapter
    )

    Write-SCfHost -Object $StringTable.NetworkSettings_Adapter_SettingDHCP
    $ResultCode = $null

    # SetGateways
    $DefaultIPGatewayArg = [System.Collections.Generic.List[String]]@()
    if ($PSCmdlet.ShouldProcess(@($NetworkAdapter, $DefaultIPGatewayArg), 'Invoke-CimMethod:SetGateways'))
    {
        $Parameters = @{
            InputObject = $NetworkAdapter
            MethodName  = 'SetGateways'
            Arguments   = @{
                DefaultIPGateway = $DefaultIPGatewayArg
            }
        }
        $ResultCode = (Invoke-CimMethod @Parameters).ReturnValue
    }

    if ($ResultCode -eq 1) { $RebootRequired = $true }
    $Failed = Write-SCfResultText $ResultCode 'SetGateways' $StringTable.NetworkSettings_SetGateways_Succeeded $StringTable.NetworkSettings_SetGateways_Failed
    if ($Failed) { return }

    # EnableDHCP
    if ($PSCmdlet.ShouldProcess($NetworkAdapter, 'Invoke-CimMethod:EnableDHCP'))
    {
        $ResultCode = (Invoke-CimMethod -InputObject $NetworkAdapter -MethodName EnableDHCP).ReturnValue
    }

    if ($ResultCode -eq 1) { $RebootRequired = $true }
    $Failed = Write-SCfResultText $ResultCode 'EnableDHCP' $StringTable.NetworkSettings_EnableDHCP_Succeeded $StringTable.NetworkSettings_EnableDHCP_Failed
    if ($Failed) { return }

    # ReleaseDHCPLease
    if ($PSCmdlet.ShouldProcess($NetworkAdapter, 'Invoke-CimMethod:ReleaseDHCPLease'))
    {
        $ResultCode = (Invoke-CimMethod -InputObject $NetworkAdapter -MethodName ReleaseDHCPLease).ReturnValue
    }

    if ($ResultCode -eq 1) { $RebootRequired = $true }
    $Failed = Write-SCfResultText $ResultCode 'ReleaseDHCPLease' $StringTable.NetworkSettings_ReleaseDHCPLease_Succeeded $StringTable.NetworkSettings_ReleaseDHCPLease_Failed
    if ($Failed) { return }

    if ($RebootRequired)
    {
        Invoke-SCfRestartPrompt
    }
    else
    {
        Read-SCfHost -Prompt $StringTable.Continue
    }
}

<#
    Set DNS Servers for adapter
    Input: Network Adapter CIM instance
#>
function Set-SCfDNSServerSearchOrder
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        $NetworkAdapter
    )

    $DNSServer = Read-SCfHost -Prompt @($StringTable.NetworkSettings_DNS_ServerPrompt, $StringTable.BlankToCancel)
    if (-not $DNSServer) { return }

    $AltDNSServer = Read-SCfHost -Prompt @($StringTable.NetworkSettings_DNS_AlternatePrompt, $StringTable.NetworkSettings_DNS_BlankNone)
    if ($AltDNSServer)
    {
        $DNSServerSearchOrderArg = [System.Collections.Generic.List[String]]@($DNSServer, $AltDNSServer)
    }
    else
    {
        $DNSServerSearchOrderArg = [System.Collections.Generic.List[String]]@($DNSServer)
    }

    $ResultCode = $null
    if ($PSCmdlet.ShouldProcess(@($NetworkAdapter, $DNSServerSearchOrderArg), 'Invoke-CimMethod:SetDNSServerSearchOrder'))
    {
        $Parameters = @{
            InputObject = $NetworkAdapter
            MethodName  = 'SetDNSServerSearchOrder'
            Arguments   = @{
                DNSServerSearchOrder = $DNSServerSearchOrderArg
            }
        }
        $ResultCode = (Invoke-CimMethod @Parameters).ReturnValue
    }

    if ($ResultCode -eq 1) { $RebootRequired = $true }
    $Failed = Write-SCfResultText $ResultCode 'SetDNSServerSearchOrder' $StringTable.NetworkSettings_SetDNSServerSearchOrder_Succeeded $StringTable.NetworkSettings_SetDNSServerSearchOrder_Failed
    if ($Failed) { return }

    if ($RebootRequired)
    {
        Invoke-SCfRestartPrompt
    }
    else {
        Read-SCfHost -Prompt $StringTable.Continue
    }
}

<#
    Clears the DNS servers and reverts to default
    Input: Network Adapter CIM instance
#>
function Reset-SCfDNSServerSearchOrder
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        $NetworkAdapter
    )

    $DNSServerSearchOrderArg = [System.Collections.Generic.List[String]]@()
    $ResultCode = $null
    if ($PSCmdlet.ShouldProcess(@($NetworkAdapter, $DNSServerSearchOrderArg), 'Invoke-CimMethod:SetDNSServerSearchOrder'))
    {
        $Parameters = @{
            InputObject = $NetworkAdapter
            MethodName  = 'SetDNSServerSearchOrder'
            Arguments   = @{
                DNSServerSearchOrder = $DNSServerSearchOrderArg
            }
        }
        $ResultCode = (Invoke-CimMethod @Parameters).ReturnValue
    }

    if ($ResultCode -eq 1) { $RebootRequired = $true }
    $Failed = Write-SCfResultText $ResultCode 'SetDNSServerSearchOrder' $StringTable.NetworkSettings_ClearDNSServerSettings_Succeeded $StringTable.NetworkSettings_ClearDNSServerSettings_Failed
    if ($Failed) { return }

    if ($RebootRequired)
    {
        Invoke-SCfRestartPrompt
    }
    else
    {
        Read-SCfHost -Prompt $StringTable.Continue
    }
}

Export-ModuleMember -Function *
