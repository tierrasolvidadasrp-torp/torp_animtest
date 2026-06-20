# Set up localization
$TextModulePath = Join-Path -Path $psScriptRoot -ChildPath "\SConfig.Text.psm1"
Import-Module -Name $TextModulePath -Force
$StringTable = Get-SCfLocalizedStringTable
$SingleCharLookup = Get-SCfSingleCharLookupTable $StringTable
$StringTable = Convert-SCfAmpersandToParentheses $StringTable # Converts single-char identifier "&" to a set of parentheses around the letter

<#
    Get the current value of the Remote Management setting
    Output: a string representation of the current value
#>
function Get-SCfPSRemotingStatus
{
    [CmdletBinding()]
    param()

    try
    {
        <#
            The simpler test for this status is to check if 'Test-WSMan' returns a result (Enabled) or errors out (Disabled),
            which we do last. However, it takes a couple seconds for this error to occur, so these nested if statements are
            an attempt to check other pieces of computer information that must be true for Remote Management to be enabled;
            if an earlier check fails, we don't have to wait for Test-WSMan to fail to know that Remote Management is disabled.
        #>
        if ((Get-Service -Name WinRM).Status -ne 'Running' -or
            (Get-NetFirewallRule -Group '@FirewallAPI.dll,-30267')[0].Enabled -eq $StringTable.False -or
            (Get-NetFirewallRule -Group '@FirewallAPI.dll,-30267')[1].Enabled -eq $StringTable.False)
        {
            return $StringTable.RemoteManagement_Disabled
        }

        # Finally, check Test-WSMan for a response
        if ([bool](Test-WSMan -ErrorAction SilentlyContinue))
        {
            return $StringTable.RemoteManagement_Enabled
        }
        else
        {
            return $StringTable.RemoteManagement_Disabled
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.RemoteManagement_Status_Failed
    }
}

<#
    Get the current value of the Remote Desktop setting
    Output: a string representation of the current value
#>
function Get-SCfRemoteDesktopStatus
{
    [CmdletBinding()]
    param()

    try
    {
        $Parameters = @{
            ClassName = 'Win32_TerminalServiceSetting'
            Namespace = 'root\CIMV2\TerminalServices'
        }
        $TerminalServiceSetting = Get-CimInstance @Parameters
        if ($TerminalServiceSetting.AllowTSConnections -eq 0)
        {
            return $StringTable.RemoteDesktop_Status_Disabled
        }
        else
        {
            $Parameters = @{
                ClassName = 'Win32_TSGeneralSetting'
                Namespace = 'root\CIMV2\TerminalServices'
                Filter    = "TerminalName='RDP-tcp'"
            }
            $TSGeneralSetting = Get-CimInstance @Parameters
            if ($TSGeneralSetting.UserAuthenticationRequired -eq 0)
            {
                return $StringTable.RemoteDesktop_Status_EnabledAll
            }
            else
            {
                return $StringTable.RemoteDesktop_Status_EnabledSecure
            }
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.RemoteDesktop_Status_Failed
    }
}

# Disables Remote Management unless $Enable flag is provided
function Get-SCfRemoteManagementSetting
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [Switch]
        $Enable
    )

    if ($Enable.IsPresent)
    {
        if ($Status -eq $StringTable.RemoteManagement_Enabled)
        {
            Write-SCfHost -Object $StringTable.RemoteManagement_AlreadyEnabled
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_Enabling
        Enable-PSRemoting -Force -SkipNetworkProfileCheck -WhatIf:$WhatIfPreference | Out-Null
        Write-SCfHost -Object $StringTable.RemoteManagement_Enabling_Success
        Read-SCfHost -Prompt $StringTable.Continue
    }
    else # Disable by default
    {
        if ($Status -eq $StringTable.RemoteManagement_Disabled)
        {
            Write-SCfHost -Object $StringTable.RemoteManagement_AlreadyDisabled
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_Disabling

        # Disable warnings temporarily -- warning is addressed via code in this function
        $SessionWarningPreference = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        Disable-PSRemoting -Force -WhatIf:$WhatIfPreference
        $WarningPreference = $SessionWarningPreference

        # Delete listeners
        if ($PSCmdlet.ShouldProcess('WSMan:\Localhost\listener\listener*', 'Remove-Item'))
        {
            Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse
        }

        # Stop WinRM and stop it from automatically running on startup
        if ($PSCmdlet.ShouldProcess('WinRM', 'Stop-Service'))
        {
            Stop-Service WinRM
        }

        if ($PSCmdlet.ShouldProcess(@('WinRM', 'StartupType', 'Disabled'), 'Set-Service'))
        {
            Set-Service WinRM -StartupType Disabled
        }

        # Disable firewall rules for group "Windows Remote Management"
        if ($PSCmdlet.ShouldProcess(@('@FirewallAPI.dll,-30267', 'Enabled:False'), 'Set-NetFirewallRule'))
        {
            Set-NetFirewallRule -Group '@FirewallAPI.dll,-30267' -Enabled False
        }

        # Set registry key if it exists (only computers that are NOT part of an AD domain)
        $Parameters = @{
            Path        = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system'
            Name        = 'LocalAccountTokenFilterPolicy'
            ErrorAction = 'SilentlyContinue'
        }

        $NotAD = Get-ItemProperty @Parameters
        $ShouldProcessItemProperty = $PSCmdlet.ShouldProcess(@(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system',
                'LocalAccountTokenFilterPolicy',
                0
            ),
            'Set-ItemProperty'
        )

        if ($NotAD -and $ShouldProcessItemProperty)
        {
            $Parameters = @{
                Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system'
                Name  = 'LocalAccountTokenFilterPolicy'
                Value = 0
            }
            Set-ItemProperty @Parameters
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_Disabling_Success
        Read-SCfHost -Prompt $StringTable.Continue
    }
}

# Disables server response to ping unless $Enable flag is provided
function Get-SCfPingSetting
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [Switch]
        $Enable
    )

    if ($Enable.IsPresent)
    {
        if ($PingStatus -eq $StringTable.RemoteManagement_Enabled)
        {
            Write-SCfHost -Object $StringTable.RemoteManagement_PingAlreadyEnabled
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_PingEnabling
        if ($PSCmdlet.ShouldProcess('FPS-ICMP4-ERQ-In', 'Enable-NetFirewallRule'))
        {
            Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_PingEnabling_Success
        Read-SCfHost -Prompt $StringTable.Continue
    }
    else
    {
        if ($PingStatus -eq $StringTable.RemoteManagement_Disabled)
        {
            Write-SCfHost -Object $StringTable.RemoteManagement_PingAlreadyDisabled
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_PingDisabling
        if ($PSCmdlet.ShouldProcess('FPS-ICMP4-ERQ-In', 'Disable-NetFirewallRule'))
        {
            Disable-NetFirewallRule -Name FPS-ICMP4-ERQ-In
        }

        Write-SCfHost -Object $StringTable.RemoteManagement_PingDisabling_Success
        Read-SCfHost -Prompt $StringTable.Continue
    }
}

# Set various Remote Management settings based on user input: returns true if setting was changed
function Get-SCfRemoteManagement
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param()

    $Status = Get-SCfPSRemotingStatus
    $PingStatus = [String]::Empty
    if ((Get-NetFirewallRule -Name FPS-ICMP4-ERQ-In).Enabled -eq $StringTable.True)
    {
        $PingStatus = $StringTable.RemoteManagement_Enabled
    }
    else
    {
        $PingStatus = $StringTable.RemoteManagement_Disabled
    }

    Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.RemoteManagement_Title)
  $($StringTable.RemoteManagement_Status -f $Status.toLower())
  $($StringTable.RemoteManagement_PingStatus -f $PingStatus.toLower())

    1) $($StringTable.RemoteManagement_MenuOptions_Enable)
    2) $($StringTable.RemoteManagement_MenuOptions_Disable)
    3) $($StringTable.RemoteManagement_MenuOptions_EnablePing)
    4) $($StringTable.RemoteManagement_MenuOptions_DisablePing)

"@

    $InputList = @('1', '2', '3', '4', [String]::Empty)
    do { $RemoteOption = Read-SCfHost -Prompt @($StringTable.SelectionPrompt, $StringTable.BlankToCancel) }
    until ($InputList -contains $RemoteOption)
    if (-not $RemoteOption) { return }

    try
    {
        switch ($RemoteOption)
        {
            '1' { Get-SCfRemoteManagementSetting -Enable }
            '2' { Get-SCfRemoteManagementSetting }
            '3' { Get-SCfPingSetting -Enable }
            '4' { Get-SCfPingSetting }
        }

        return $true
    }
    catch
    {
        $Message = [String]::Empty
        switch ($RemoteOption)
        {
            '1' { $Message = $StringTable.RemoteManagement_Enabling_Failed }
            '2' { $Message = $StringTable.RemoteManagement_Disabling_Failed }
            '3' { $Message = $StringTable.RemoteManagement_PingEnabling_Failed }
            '4' { $Message = $StringTable.RemoteManagement_PingDisabling_Failed }
        }

        Invoke-SCfErrorHandler -Error $_ -Message $Message
        return $false
    }
}

<#
    Set Remote Desktop setting based on user input: returns true if setting was changed
    Input: current remote desktop setting, for display
#>
function Set-SCfRemoteDesktopSetting
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $CurrentSetting
    )

    Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.RemoteDesktop_Title)
  $($StringTable.RemoteDesktop_Current) $CurrentSetting

"@

    $InputList = $SingleCharLookup['RemoteDesktop_EnablePrompt']
    do { $RdpSelection = Read-SCfHost -Prompt @($StringTable.RemoteDesktop_EnablePrompt, $StringTable.BlankToCancel) }
    until ($InputList -contains $RdpSelection)
    if (-not $RdpSelection) { return }

    try
    {
        $Enable = $RdpSelection -eq $InputList[0]
        if ($Enable)
        {
            Write-SCfHost -Indent 0 -Object @"

    1) $($StringTable.RemoteDesktop_MenuOptions_NLA)
    2) $($StringTable.RemoteDesktop_MenuOptions_Any)

"@
            $InputList = @('1', '2', [String]::Empty);
            do { $RdpEnableSelection = Read-SCfHost -Prompt @($StringTable.SelectionPrompt, $StringTable.BlankToCancel) }
            until ($InputList -contains $RdpEnableSelection)
            if (-not $RdpEnableSelection) { return }
            Write-SCfHost -Object $StringTable.RemoteDesktop_Enabling
        }
        else # 'Disable'
        {
            Write-SCfHost -Object $StringTable.RemoteDesktop_Disabling
        }

        
        $Parameters = @{
            ClassName = 'Win32_TerminalServiceSetting'
            Namespace = 'root\CIMV2\TerminalServices'
        }
        $TerminalServiceSetting = Get-CimInstance @Parameters

        if($PSCmdlet.ShouldProcess($Enable, 'Invoke-CimMethod:SetAllowTsConnections'))
        {
            $Parameters = @{
                InputObject = $TerminalServiceSetting
                MethodName  = 'SetAllowTSConnections'
                Arguments   = @{
                    AllowTSConnections = [int]$Enable
                    ModifyFirewallException = [int]$true
                }
            }
            Invoke-CimMethod @Parameters
        }

        if ($Enable)
        {
            $EnableNLA = $RdpEnableSelection -eq $InputList[0]
            $Parameters = @{
                ClassName = 'Win32_TSGeneralSetting'
                Namespace = 'root\CIMV2\TerminalServices'
                Filter    = "TerminalName='RDP-tcp'"
            }
            $TSGeneralSetting = Get-CimInstance @Parameters
            if ($PSCmdlet.ShouldProcess($EnableNLA, 'SetUserAuthenticationRequired'))
            {
                $Parameters = @{
                    InputObject = $TSGeneralSetting
                    MethodName  = 'SetUserAuthenticationRequired'
                    Arguments   = @{
                        UserAuthenticationRequired = [int]$EnableNLA
                    }
                }
                Invoke-CimMethod @Parameters
            }
        }

        Write-SCfHost -Object $StringTable.RemoteDesktop_Success
        Read-SCfHost -Prompt $StringTable.Continue
        return $true
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.RemoteDesktop_Failed
        return $false
    }
}

Export-ModuleMember -Function *
