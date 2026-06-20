# Set up localization
$TextModulePath = Join-Path -Path $psScriptRoot -ChildPath "\SConfig.Text.psm1"
Import-Module -Name $TextModulePath -Force
$StringTable = Get-SCfLocalizedStringTable
$SingleCharLookup = Get-SCfSingleCharLookupTable $StringTable
$StringTable = Convert-SCfAmpersandToParentheses $StringTable # Converts single-char identifier "&" to a set of parentheses around the letter

# Loads SConfigHelper DLL into current PowerShell session
function Get-SConfigHelper
{
    [CmdletBinding()]
    param()

    $SConfigHelperPath = Join-Path -Path $psScriptRoot -ChildPath 'SConfigHelper.dll'
    $TelemetryDLLPath = Join-Path -Path $env:windir -ChildPath '\System32\DiagnosticDataSettings.dll'
    $SoftwareLicensingDLLPath = Join-Path -Path $env:windir -ChildPath '\System32\slc.dll'

    # Check for DLLs
    if ((-not (Test-Path $SConfigHelperPath)) -or
        (-not (Test-Path $TelemetryDLLPath)) -or
        (-not (Test-Path $SoftwareLicensingDLLPath)))
    {
        Write-SCfHost -Object $StringTable.MissingResource
        Read-SCfHost -Prompt $StringTable.Continue
    }
    elseif (-not ([System.Management.Automation.PSTypeName]'Microsoft.Windows.Server.SConfigHelper').Type)
    {
        # If the type does not exist yet, add it
        Add-Type -Path $SConfigHelperPath
    }
}

<#
    Get the current value of the telemetry setting
    Output: a string representation of the current value
#>
function Get-SCfTelemetrySetting
{
    [CmdletBinding()]
    param()

    try
    {
        if (-not ([System.Management.Automation.PSTypeName]'Microsoft.Windows.Server.SConfigHelper').Type)
        {
            Get-SConfigHelper # Load SConfigHelper if needed
        }

        $Level = [Microsoft.Windows.Server.SConfigHelper]::GetTelemetryLevel()
        switch ($Level)
        {
            '0' { return $StringTable.TelemetrySetting_MenuOptions_Off }
            '1' { return $StringTable.TelemetrySetting_MenuOptions_Required }
            # '2' is 'Enhanced', which has been deprecated
            '3' { return $StringTable.TelemetrySetting_MenuOptions_Optional }
            default { return $StringTable.TelemetrySetting_Error }
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.TelemetrySetting_Status_Failed
    }
}

<#
    Set the computer name based on user input; if Inline switch is set, the header will not be displayed
    Inputs:
        CurrentSetting: current computer name
        InDomain: boolean, whether or not computer is domain-joined
        Inline: switch variable; if present, header / CurrentSetting are not displayed
        Username: if username is already known, user will not be prompted for it
    Output: boolean indicating whether or not the computer name was changed
#>
function Set-SCfComputerName
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $CurrentSetting,

        [Parameter(Mandatory=$true)]
        $InDomain,

        [Parameter(Mandatory=$false)]
        [Switch]
        $Inline,

        [Parameter(Mandatory=$false)]
        [String]
        $Username
    )

    if (-not $Inline)
    {
        Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.ComputerName_Title)
  $($StringTable.ComputerName_Current) $CurrentSetting

"@
    }

    $UserInput = Read-SCfHost -Prompt @($StringTable.ComputerName_NewNamePrompt, $StringTable.BlankToCancel)
    if (-not $UserInput) { return $false }

    try
    {
        # If machine is in a domain
        if ($InDomain)
        {
            # Enter authorized user
            if (-not $Username) { $Username = Read-SCfHost -Prompt @($StringTable.AuthorizedPrompt, $StringTable.BlankToCancel) }
            if (-not $Username) { return $false } # Blank=Cancel

            $Password = Read-SCfHost -Prompt $($StringTable.AuthorizedPasswordPrompt -f $Username) -AsSecureString

            $Parameters = @{
                TypeName     = 'System.Management.Automation.PSCredential'
                ArgumentList = ([String]$Username, [System.Security.SecureString]$Password)
            }
            $Credential = New-Object @Parameters

            Write-SCfHost -Object $StringTable.ComputerName_ChangingName

            if ($PSCmdlet.ShouldProcess($UserInput, 'Rename-Computer'))
            {
                $Parameters = @{
                    NewName          = $UserInput
                    DomainCredential = $Credential
                    Force            = $true
                    WhatIf           = $WhatIfPreference
                }
                Rename-Computer @Parameters
            }
        }
        else
        {
            Write-SCfHost -Object $StringTable.ComputerName_ChangingName
            if ($PSCmdlet.ShouldProcess($UserInput, 'Rename-Computer'))
            {
                Rename-Computer -NewName $UserInput -WhatIf:$WhatIfPreference
            }
        }

        Invoke-SCfRestartPrompt
        return $true
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.ComputerName_Failed
    }
}

<#
    Set telemetry setting based on user input
    Input: CurrentOS, current OS Name
    Output: boolean indicating whether or not the telemetry setting was changed
#>
function Set-SCfTelemetrySetting
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        $CurrentOS
    )

    Write-SCfHost -Indent 0 -Object $(Get-SCfHeader $StringTable.TelemetrySetting_Title)
    $WrappedLines = Get-SCfWrappedText $($StringTable.TelemetrySetting_HelpImprove -f $CurrentOS)
    foreach ($Line in $WrappedLines) { Write-SCfHost -Object $Line }

    $UserInput = Read-SCfHost -Indent 0 @"

  $($StringTable.TelemetrySetting_MoreInfoLink)

  $($StringTable.TelemetrySetting_PrivacyLink)

  $($StringTable.TelemetrySetting_ChangePrompt) $($StringTable.YesNoSuffix)
"@
    try
    {
        if ($UserInput -ne $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
        {
            Write-SCfHost -Object $StringTable.Canceling
            return $false
        }

        Write-SCfHost -Indent 0 -Object @"

  $($StringTable.TelemetrySetting_AvailableSettings)

    1) $($StringTable.TelemetrySetting_MenuOptions_Off)
    2) $($StringTable.TelemetrySetting_MenuOptions_Required)
    3) $($StringTable.TelemetrySetting_MenuOptions_Optional)

"@
        $InputList = @('1', '2', '3', [String]::Empty)
        do { $TelemetryOption = Read-SCfHost -Prompt @($StringTable.TelemetrySetting_MenuOptions_Prompt, $StringTable.BlankToCancel) }
        until ($InputList -contains $TelemetryOption)

        # Mapping based on SConfigTelemetryLevel enum in SConfigHelper.cs
        switch ($TelemetryOption)
        {
            '1' { $Level = 0 }
            '2' { $Level = 1 }
            # Level '2' is 'Enhanced', which has been deprecated
            '3' { $Level = 3 }
            default { return $false }
        }

        $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $UserSid = $CurrentPrincipal.Identity.User
        $ProcessName = 'SConfig'

        $Success = $false
        if ($PSCmdlet.ShouldProcess($Level, 'SetTelemetryLevel'))
        {
            $Success = [Microsoft.Windows.Server.SConfigHelper]::SetTelemetryLevel($Level, $UserSid, $ProcessName)
        }

        if (-not $Success)
        {
            Write-SCfHost -Object $StringTable.TelemetrySetting_Configure_Failed
            Read-SCfHost -Prompt $StringTable.Continue
        }

        return $true
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_
    }
}

# Guides the user through Windows Activation
function Invoke-SCfWindowsActivation
{
    [CmdletBinding()]
    param()

    Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.WindowsActivation_Title)
    1) $($StringTable.WindowsActivation_MenuOptions_DisplayLicense)
    2) $($StringTable.WindowsActivation_MenuOptions_Activate)
    3) $($StringTable.WindowsActivation_MenuOptions_InstallKey)

"@
    $InputList = @('1', '2', '3', [String]::Empty)
    do { $ActivationOption = Read-SCfHost -Prompt @($StringTable.SelectionPrompt, $StringTable.BlankToCancel) }
    until ($InputList -contains $ActivationOption)

    $ScriptPath = Join-Path -Path $env:windir -ChildPath '\system32\slmgr.vbs'
    switch ($ActivationOption)
    {
        '1' { $Result = cscript $ScriptPath /dli //NoLogo }
        '2' { $Result = cscript $ScriptPath /ato //NoLogo }
        '3' {
            do
            { $UserInput = Read-SCfHost -Prompt $StringTable.WindowsActivation_KeyPrompt } until ($UserInput)
            $Result = cscript $ScriptPath //NoLogo /ipk $UserInput
        }
    }
    Write-SCfHost -Indent 0
    foreach ($Line in $Result)
    {
        if ($Line) { Write-SCfHost -Indent 2 -Object $Line }
    }

    Write-SCfHost -Indent 0
    Read-SCfHost -Prompt $StringTable.Continue
}

<#
    Displays the restart prompt to the user
    This method assumes that a previous cmdlet has displayed a message akin to "WARNING: The changes will take effect after you restart the computer"
#>
function Invoke-SCfRestartPrompt
{
    [CmdletBinding()]
    param()

    $UserInput = Read-SCfHost -Prompt @($StringTable.RestartPrompt, $StringTable.YesNoSuffix)
    if ($UserInput -eq $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
    {
        Restart-Computer
    }
}

# Prompts the user to log off: returns true if user answers 'yes'
function Invoke-SCfLogOff
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()

    $UserInput = Read-SCfHost -Prompt @($StringTable.ConfirmationPrompts_LogOff, $StringTable.YesNoSuffix)
    if ($UserInput -eq  $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
    {
        Invoke-Command  -ScriptBlock { logoff (Get-Process -PID $pid).SessionID }
        return $true
    }
}

# Prompts the user to restart: returns true if user answers 'yes'
function Invoke-SCfRestart
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()

    $UserInput = Read-SCfHost -Prompt @($StringTable.ConfirmationPrompts_Restart, $StringTable.YesNoSuffix)
    if ($UserInput -eq $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
    {
        Restart-Computer
        return $true
    }
}

# Prompts the user to shut down: returns true if user answers 'yes'
function Invoke-SCfShutDown
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param()

    $UserInput = Read-SCfHost -Prompt @($StringTable.ConfirmationPrompts_ShutDown, $StringTable.YesNoSuffix)
    if ($UserInput -eq $SingleCharLookup['YesNoSuffix'][0]) # 'Yes'
    {
        Stop-Computer
        return $true
    }
}

<#
    Add a local administrator based on user input: if not domain-joined, the users being added must first be created
    Input: InDomain, a boolean indicating whether or not the computer is domain-joined
#>
function Add-SCfLocalAdmin
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $InDomain
    )

    Write-SCfHost -Indent 0 -Object $(Get-SCfHeader $StringTable.AddLocalAdmin_Title)
    $Username = [String]::Empty
    if ($InDomain)
    {
        $Attempts = 0
        $Max = 5
        while (-not $Username -and $Attempts -ne $Max)
        {
            $Attempts++
            $Username = Read-SCfHost -Prompt @($StringTable.AddLocalAdmin_AccountPrompt_InDomain, $StringTable.BlankToCancel)

            if (-not $Username) { return }
            if (-not $(Test-SCfUserExistence $Username))
            {
                Write-SCfHost -Object $($StringTable.AddLocalAdmin_UserNotExist -f $Username)
                $Username = [String]::Empty
            }
        }
        if ($Attempts -eq $Max)
        {
            Write-SCfHost -Object $($StringTable.AddLocalAdmin_TooManyAttempts -f $Max)
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }
    }
    else
    {
        $Username = Read-SCfHost -Indent 0 @"
  $($StringTable.AddLocalAdmin_AccountPrompt_InWorkgroup_Line1)
  $($StringTable.AddLocalAdmin_AccountPrompt_InWorkgroup_Line2) $($StringTable.BlankToCancel)
"@
        if (-not $Username) { return }
    }

    if (-not $InDomain -and -not $(Test-SCfUserExistence $Username))
    {
        $Attempts = 0
        $Max = 10
        while (-not ($Attempts -eq $Max -or $ValidPassword))
        {
            try
            {
                $Attempts++
                $Password = Read-SCfHost -Prompt $($StringTable.AddLocalAdmin_PasswordPrompt -f $Username) -AsSecureString
                New-LocalUser -Name $Username -Password $Password | Out-Null
                Write-SCfHost -Object $StringTable.AddLocalAdmin_CreatedUser
                $ValidPassword = $true
            }
            catch [Microsoft.PowerShell.Commands.InvalidPasswordException]
            {
                Write-SCfHost -Object $StringTable.AddLocalAdmin_InvalidPassword
                if (-not ($Attempts -eq $Max)) { Write-SCfHost -Object $StringTable.AddLocalAdmin_Retrying }
            }
        }

        if ($Attempts -eq $Max)
        {
            Write-SCfHost -Object $($StringTable.AddLocalAdmin_TooManyAttempts -f $Max)
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }
    }

    try
    {
        Write-SCfHost -Object $($StringTable.AddLocalAdmin_AddingLocalAdmin -f $Username)
        Add-LocalGroupMember -SID 's-1-5-32-544' -Member $Username

        Write-SCfHost -Object $($StringTable.AddLocalAdmin_Success -f $Username)
        Read-SCfHost -Prompt $StringTable.Continue
    }
    catch [Microsoft.PowerShell.Commands.MemberExistsException]
    {
        Write-SCfHost -Object $($StringTable.AddLocalAdmin_MemberExists -f $Username)
        Read-SCfHost -Prompt $StringTable.Continue
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.AddLocalAdmin_Failed
    }
}

<#
    Check if user exists
    Input: Username
    Output: returns true if local user exists
#>
function Test-SCfUserExistence
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $Username
    )

    $Users = Get-LocalUser
    return $($Users.Name -contains $Username)
}

Export-ModuleMember -Function *
