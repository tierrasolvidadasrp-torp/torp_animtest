# Localization Setup
$StringTable = Get-SCfLocalizedStringTable
$SingleCharLookup = Get-SCfSingleCharLookupTable $StringTable
$StringTable = Convert-SCfAmpersandToParentheses $StringTable # Converts single-char identifier "&" to a set of parentheses around the letter

$LaunchedAtSignIn = $false

# Settings filename & default values
$UserSettingsFile = 'powershell.config.json'
$DefaultUserSettings = @{
    DebugOutput    = $false # verbose output, terminal never cleared
    AutoLaunch     = $true # launch SConfig at sign-in, via ServerCore Shell Launcher
    AutoLaunchHint = $true # notify the user that they can opt-out of autolaunch behavior
    AutoUpdate     = $true # (not implemented) automatically check for SConfig updates when SConfig starts
}

<#
    Load computer data needed when SConfig starts
    Output: "global" hashtable, $Data (not actually global variable, $Data is passed between functions)
#>
function Update-SCfScriptData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Data
    )

    try
    {
        Clear-Host
        Write-SCfHost -Indent 0 -Object $StringTable.Loading

        # Update script data where needed
        if ($UpdateNeeded.Common)           { $Data = Update-SCfCommonData $Data }
        if ($UpdateNeeded.DomainWorkgroup)  { $Data = Update-SCfDomainWorkgroupData $Data}
        if ($UpdateNeeded.ComputerName)     { $Data['ComputerName'] = $env:computername }
        if ($UpdateNeeded.RemoteManagement) { $Data['RemoteManagement'] = Get-SCfPSRemotingStatus }
        if ($UpdateNeeded.UpdateSetting)    { $Data['UpdateSetting'] = Get-SCfUpdateSetting }
        if ($UpdateNeeded.RemoteDesktop)    { $Data['RemoteDesktop'] = Get-SCfRemoteDesktopStatus }
        if ($UpdateNeeded.TelemetrySetting) { $Data['TelemetrySetting'] = Get-SCfTelemetrySetting }

        # Reset data changed flags
        foreach ($key in $($UpdateNeeded.keys))
        {
            $UpdateNeeded[$key] = $false
        }

        return $Data
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.FailedToQuery
    }
}

# Update data used across various functions
function Update-SCfCommonData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Data
    )

    # Get system resources
    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $OSCIM = Get-CimInstance -Class Win32_OperatingSystem

    # Get common script data
    $Data['ElevatedSession'] = $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $Data['CurrentOS'] = $OSCIM.Caption.Replace( 'Microsoft ', [String]::Empty )
    $Data['AllowPreviewChannelOptIn'] = $true # [bool]([Microsoft.Windows.Server.SConfigHelper]::AllowPreviewChannelOptIn())
    $Data['HideWindowsActivation'] = [bool]([Microsoft.Windows.Server.SConfigHelper]::WindowsActivationHidden())
    $Data['FeatureUpdateVersion'] = [Microsoft.Windows.Server.SConfigHelper]::FeatureUpdateVersion()
    return $Data
}

# Update data about domain/workgroup membership
function Update-SCfDomainWorkgroupData
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Data
    )

    $CSCIM = Get-CimInstance -Class Win32_ComputerSystem
    $Data['InDomain'] = $CSCIM.PartOfDomain
    if ($Data['InDomain'])
    {
        $Data['DomainWorkgroupLabel'] = $($StringTable.DomainWorkgroup_Domain + ' ')
        $Data['DomainWorkgroup'] = $CSCIM.Domain
    }
    elseif ($CSCIM.Workgroup)
    {
        $Data['DomainWorkgroupLabel'] = $($StringTable.DomainWorkgroup_Workgroup + ' ')
        $Data['DomainWorkgroup'] = $CSCIM.Workgroup
    }
    else
    {
        $Data['DomainWorkgroupLabel'] = [String]::Empty
        $Data['DomainWorkgroup'] = $StringTable.Unknown
    }

    return $Data
}

# Find the path to the user settings file for SConfig
function Get-SCfCurrentUserSettingsFilepath
{
    [CmdletBinding()]
    param()

    $CurrentUserPath = Split-Path $PROFILE.CurrentUserCurrentHost
    $CurrentUserSettings = Join-Path -Path $CurrentUserPath -ChildPath $UserSettingsFile
    return $CurrentUserSettings
}

# Find the path to the "all users" settings file for SConfig
function Get-SCfAllUsersSettingsFilepath
{
    [CmdletBinding()]
    param()

    return $(Join-Path -Path $PSHOME -ChildPath $UserSettingsFile)
}

# Loads user settings and returns them as a hashtable
function Get-SCfUserSettings
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $Path
    )

    # Load global SConfig settings as JSON
    $SettingsJson = $null
    if (Test-Path -Path $Path -PathType leaf)
    {
        $SettingsJson = $(Get-Content $Path | ConvertFrom-Json).SConfig
    }

    $Settings = @{}
    if ($SettingsJson)
    {
        foreach ($Property in $SettingsJson.PSObject.Properties)
        {
            $Settings[$Property.Name] = $Property.Value
        }
    }

    return $Settings
}

<#
    Load SConfig Settings
        Function is dependent on $UserSettingsFile and $DefaultUserSettings,
        defined at the start of this script.

        These custom settings are contained in the powershell.config.json, under
        a custom attribute "SConfig". Other code consuming powershell.config.json
        will ignore the "SConfig" attribute.
#>
function Get-SConfig
{
    [CmdletBinding()]
    param()

    $AllUsersPath = Get-SCfAllUsersSettingsFilepath
    $AllUsersSettings = Get-SCfUserSettings -Path $AllUsersPath

    $CurrentUserPath = Get-SCfCurrentUserSettingsFilepath
    $CurrentUserSettings = Get-SCfUserSettings -Path $CurrentUserPath

    # Load default settings
    $Settings = $DefaultUserSettings.Clone()

    # Overwrite with any settings defined globally
    foreach ($Key in $AllUsersSettings.Keys)
    {
        $Settings[$Key] = $AllUsersSettings[$Key]
    }

    # Then, overwrite with any settings defined for the current user
    foreach ($Key in $CurrentUserSettings.Keys)
    {
        $Settings[$Key] = $CurrentUserSettings[$Key]
    }

    return $Settings
}

<#
    Builds the main menu
    Output: a here-string containing all the applicable menu options and corresponding values
#>
function Get-SCfMenuPage
{
    [CmdletBinding()]
    [OutputType([String])]
    param()

    # Define option groups
    $OptionGroup1 = @"
    1)  $($StringTable.MenuOptions_DomainWorkGroup)$(Get-SCfMenuColumnPadding $StringTable.MenuOptions_DomainWorkGroup)$($Data['DomainWorkgroupLabel'])$($Data['DomainWorkgroup'])
    2)  $($StringTable.MenuOptions_ComputerName)$(Get-SCfMenuColumnPadding $StringTable.MenuOptions_ComputerName)$($Data['ComputerName'])
    3)  $($StringTable.MenuOptions_AddLocalAdmin)
    4)  $($StringTable.MenuOptions_RemoteManagement)$(Get-SCfMenuColumnPadding $StringTable.MenuOptions_RemoteManagement)$($Data['RemoteManagement'])
"@

    $OptionGroup2 = @"
    5)  $($StringTable.MenuOptions_UpdateSetting)$(Get-SCfMenuColumnPadding $StringTable.MenuOptions_UpdateSetting)$($Data['UpdateSetting'])
    6)  $($StringTable.MenuOptions_InstallUpdates)
    7)  $($StringTable.MenuOptions_RemoteDesktop)$(Get-SCfMenuColumnPadding $StringTable.MenuOptions_RemoteDesktop)$($Data['RemoteDesktop'])
"@

    $OptionGroup3 = @"
    8)  $($StringTable.MenuOptions_NetworkSettings)
    9)  $($StringTable.MenuOptions_DateTime)
    10) $($StringTable.MenuOptions_TelemetrySetting)$(Get-SCfMenuColumnPadding $StringTable.MenuOptions_TelemetrySetting)$($Data['TelemetrySetting'])
"@

    if (-not $Data['HideWindowsActivation'])
    {
        $OptionGroup3 += @"

    11) $($StringTable.MenuOptions_WindowsActivation)
"@
    }

    $OptionGroup4 = @"
    12) $($StringTable.MenuOptions_LogOffUser)
    13) $($StringTable.MenuOptions_RestartServer)
    14) $($StringTable.MenuOptions_ShutDownServer)
    15) $($StringTable.MenuOptions_ExitToCommandLine)
"@

    return @"

$OptionGroup1

$OptionGroup2

$OptionGroup3

$OptionGroup4

  $($StringTable.MenuOptions_Prompt)
"@
}

<#
    Builds the full main menu UI and prompts the user to select an option
    Output: the user's menu selection
#>
function Get-SCfMenuSelection
{
    [CmdletBinding()]
    param()

    Clear-Host
    $MenuTitle = $StringTable.Title + ' ' + $Data['CurrentOS']
    $Header = Get-SCfHeader $($MenuTitle)
    $MenuPage = Get-SCfMenuPage

    if (-not $Data['ElevatedSession'])
    {
        Write-Warning -Message $StringTable.NotElevatedWarning
    }

    if ($LaunchedAtSignIn -and $Settings['AutoLaunchHint'])
    {
        Write-Warning -Message $StringTable.AutoLaunchOptOut
    }

    return Read-SCfHost -Indent 0 -Prompt ($Header + $MenuPage)
}

# Set SConfig configuration file
function Set-SConfig
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [Switch]
        $Interactive,

        [Parameter(Mandatory=$false)]
        [Boolean]
        $DebugOutput,

        [Parameter(Mandatory=$false)]
        [Boolean]
        $AutoLaunch,

        [Parameter(Mandatory=$false)]
        [Boolean]
        $AutoLaunchHint,

        [Parameter(Mandatory=$false)]
        [Boolean]
        $AutoUpdate,

        [Parameter(Mandatory=$false)]
        [Switch]
        $AllUsers
    )

    try
    {
        # No arguments are provided (or only "-AllUsers", which is invalid on its own)
        if ($PSBoundParameters.Keys.Count -eq 0 -or
            ($PSBoundParameters.Keys.Count -eq 1 -and $AllUsers.IsPresent))
        {
            Write-Error -Message $StringTable.SConfigSettings_InvalidArgsError
        }

        # This is used often, renaming to $GUI for readability
        $GUI = $Interactive.IsPresent
        if ($GUI)
        {
            # Write settings
            $CurrentSettings = Get-SConfig
            Write-SConfig -Settings $CurrentSettings
            $SettingDisplayStrings = @{
                'DebugOutput'    = $StringTable.SConfigSettings_DebugOutput.toLower()
                'AutoLaunch'     = $StringTable.SConfigSettings_AutoLaunch.toLower()
                'AutoLaunchHint' = $StringTable.SConfigSettings_AutoLaunchHint.toLower()
                'AutoUpdate'     = $StringTable.SConfigSettings_AutoUpdate.toLower()
            }

            Write-SCfHost -Indent 0 -Object @"
   1) Toggle '$($SettingDisplayStrings['DebugOutput'])'
   2) Toggle '$($SettingDisplayStrings['AutoLaunch'])'
   3) Toggle '$($SettingDisplayStrings['AutoLaunchHint'])'
   4) Toggle '$($SettingDisplayStrings['AutoUpdate'])'

"@

            $InputList = @('1', '2', '3', '4', [String]::Empty)
            do { $SettingIndex = Read-SCfHost -Prompt @($StringTable.SelectionPrompt, $StringTable.BlankToCancel) }
            until ($InputList -contains $SettingIndex)
            if (-not $SettingIndex) { return }

            $SettingKeys = @{
                '1' = 'DebugOutput'
                '2' = 'AutoLaunch'
                '3' = 'AutoLaunchHint'
                '4' = 'AutoUpdate'
            }

            # Prompt user for scope of change
            $InputList = $SingleCharLookup['SConfigSettings_ScopePrompt']
            do { $Scope = Read-SCfHost -Prompt @($StringTable.SConfigSettings_ScopePrompt, $StringTable.BlankToCancel) }
            until ($InputList -contains $Scope)
            if (-not $Scope) { return }
        }

        if ($GUI) { $SettingsToChange += $SettingKeys[$SettingIndex] }
        else      { $SettingsToChange += $PSBoundParameters.Keys }

        foreach ($Setting in $SettingsToChange)
        {
            if ($Setting -eq 'AllUsers') { break }

            # "Toggle" setting if using GUI, otherwise get value from parameter
            if ($GUI) { $NewValue = -not $($CurrentSettings[$Setting]) }
            else      { $NewValue = $PSBoundParameters[$Setting] }

            # Make change for all users
            $AllUsersScope = $GUI -and $Scope -eq $InputList[0]
            if (($GUI -and $AllUsersScope) -or ((-not $GUI) -and $AllUsers.IsPresent))
            {
                $Filepath = Get-SCfAllUsersSettingsFilepath
            }
            # Make change for current user
            else
            {
                $Filepath = Get-SCfCurrentUserSettingsFilepath
            }

            if ($PSCmdlet.ShouldProcess(@($FilePath, $Setting, $NewValue), 'Write-SCfSettingsFile'))
            {
                $Parameters = @{
                    FilePath = $FilePath
                    Setting  = $Setting
                    Value    = $NewValue
                    WhatIf   = $WhatIfPreference
                }
                Write-SCfSettingsFile @Parameters
            }
        }

        if ($GUI)
        {
            Read-SCfHost -Prompt @($StringTable.SConfigSettings_Success, $StringTable.Continue)
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.SConfigSettings_Failed
    }
}

<#
    Write selected user setting to settings file
    Inputs:
        Filepath: path to settings file to update
        Setting: setting to update
        Value: new value for setting
#>
function Write-SCfSettingsFile
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $Filepath,

        [Parameter(Mandatory=$true)]
        [String]
        $Setting,

        [Parameter(Mandatory=$true)]
        $Value
    )

    $Directory = Split-Path $Filepath
    $FileExists = $true
    if (-not (Test-Path $Directory))
    {
        if ($PSCmdlet.ShouldProcess($Directory, 'New-Item'))
        {
            $Parameters = @{
                Path     = $Directory
                ItemType = 'directory'
                WhatIf   = $WhatIfPreference
            }
            New-Item @Parameters | Out-Null
        }
        $FileExists = $false
    }
    elseif (-not (Test-Path $Filepath -PathType leaf))
    {
        $FileExists = $false
    }

    $CurrentSettings = Get-SCfUserSettings -Path $Filepath
    $CurrentSettings[$Setting] = $Value

    # Default content object if no file exists
    $Content = [PSCustomObject]@{
        'SConfig' = [PSCustomObject]@{}
    }

    if ($FileExists)
    {
        $Content = $(Get-Content $Filepath | ConvertFrom-Json)
    }

    # If file exists but has no SConfig entry, add it
    if (-not $Content.SConfig)
    {
        $Content | Add-Member -NotePropertyMembers $(@{ 'SConfig' = [PSCustomObject]@{} })
    }

    # Set value and write to file
    $Content.SConfig = [PSCustomObject]$CurrentSettings
    if ($PSCmdlet.ShouldProcess($Filepath, 'Set-Content'))
    {
        $Parameters = @{
            Path   = $Filepath
            Value  = $($Content | ConvertTo-Json)
            WhatIf = $WhatIfPreference
        }
        Set-Content @Parameters
    }
}

# Set SConfig settings to default user settings (only for current user unless -AllUsers is specifed)
function Reset-SConfig
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [Switch]
        $AllUsers
    )

    $Arguments = $DefaultUserSettings.Clone()
    $Arguments['WhatIf'] = $WhatIfPreference
    if ($AllUsers.IsPresent) { $Arguments['AllUsers'] = $true }
    Set-SConfig @Arguments
}

# Empty function used to nullify Clear-Host in Debug scenarios
function Clear-Host-Debug { }

# Access SConfig with "logon" behavior
function Invoke-SConfigLogon
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $Settings = Get-SConfig
    if ($Settings['AutoLaunch'])
    {
        $LaunchedAtSignIn = $true # signal that opt-out warning should be displayed
        Invoke-SConfig -WhatIf:$WhatIfPreference
    }
}

# This module's "main" function, and the manual entrypoint for end users
function Invoke-SConfig
{
    [CmdletBinding(SupportsShouldProcess)]
    [Alias("SConfig")]
    param(
        [Parameter(Mandatory=$false)]
        [Switch]
        $DebugOutput
    )

    # Get SConfig settings
    $SConfigSettings = Get-SConfig

    <#
        If $Debug is set to $true:
        - Terminal output won't be cleared between operations
        - Error messages will include stack traces
    #>
    $DebugFlag = $($DebugOutput -or $SConfigSettings.DebugOutput)
    if ($DebugFlag)
    {
        New-Alias -Name 'Clear-Host' -Value 'Clear-Host-Debug'
    }

    # Load SConfigHelper DLL
    Get-SConfigHelper -ErrorAction Stop

    # Set up data model
    $Data = @{}
    $UpdateNeeded = @{
        Common           = $true
        DomainWorkGroup  = $true
        ComputerName     = $true
        RemoteManagement = $true
        UpdateSetting    = $true
        RemoteDesktop    = $true
        TelemetrySetting = $true
    }

    $ShutDown = $false
    do
    {
        $Data = Update-SCfScriptData $Data -ErrorAction Stop
        switch (Get-SCfMenuSelection)
        {
            '1' {
                Clear-Host
                $Parameters = @{
                    CurrentSetting = $Data['DomainWorkgroup']
                    CurrentLabel   = $Data['DomainWorkgroupLabel']
                    InDomain       = $Data['InDomain']
                    ErrorAction    = 'Stop'
                    WhatIf         = $WhatIfPreference
                }
                $UpdateNeeded.DomainWorkGroup = Set-SCfDomainWorkGroup @Parameters
            }
            '2' {
                Clear-Host
                $Parameters = @{
                    CurrentSetting = $Data['ComputerName']
                    InDomain       = $Data['InDomain']
                    ErrorAction    = 'Stop'
                    WhatIf         = $WhatIfPreference
                }
                $UpdateNeeded.ComputerName = Set-SCfComputerName @Parameters
            }
            '3' { Clear-Host; Add-SCfLocalAdmin -InDomain $Data['InDomain'] -ErrorAction Stop }
            '4' { Clear-Host; $UpdateNeeded.RemoteManagement = Get-SCfRemoteManagement -ErrorAction Stop -WhatIf:$WhatIfPreference }
            '5' {
                Clear-Host
                # Set-UpdateSetting may invoke its own page, so expected clear-host behavior is communicated via -DebugOutput
                $Parameters = @{
                    CurrentOS                = $Data['CurrentOS']
                    AllowPreviewChannelOptIn = $Data['AllowPreviewChannelOptIn']
                    DebugOutput              = $DebugFlag
                    ErrorAction              = 'Stop'
                }
                $UpdateNeeded.UpdateSetting = Set-SCfUpdateSetting @Parameters
            }
            '6' {
                Clear-Host
                # Invoke-SCfInstallUpdate invokes its own page, so expected clear-host behavior is communicated via -DebugOutput
                $Parameters = @{
                    IsElevatedSession        = $Data['ElevatedSession']
                    FeatureUpdateVersion     = $Data['FeatureUpdateVersion']
                    DebugOutput              = $DebugFlag
                    ErrorAction              = 'Stop'
                }
                Invoke-SCfInstallUpdate @Parameters
            }
            '7' {
                Clear-Host
                $Parameters = @{
                    CurrentSetting = $Data['RemoteDesktop']
                    ErrorAction    = 'Stop'
                    WhatIf         = $WhatIfPreference
                }
                $UpdateNeeded.RemoteDesktop = Set-SCfRemoteDesktopSetting @Parameters
            }
            '8' {
                Clear-Host
                # Set-SCfNetworkSetting invokes its own page, so expected clear-host behavior is communicated via -DebugOutput
                $Parameters = @{
                    DebugOutput = $DebugFlag
                    ErrorAction = 'Stop'
                    WhatIf      = $WhatIfPreference
                }
                Set-SCfNetworkSetting @Parameters
            }
            '9' { timedate.cpl }
            '10' {
                Clear-Host
                $Parameters = @{
                    CurrentOS   = $Data['CurrentOS']
                    ErrorAction = 'Stop'
                    WhatIf      = $WhatIfPreference
                }
                $UpdateNeeded.TelemetrySetting = Set-SCfTelemetrySetting @Parameters
            }
            '11' {
                Clear-Host
                # This conditional behavior stops users from accessing input "11" when the option is hidden
                if (-not $Data['HideWindowsActivation']) { Invoke-SCfWindowsActivation -ErrorAction Stop }
            }
            '12' { $ShutDown = Invoke-SCfLogOff }
            '13' { $ShutDown = Invoke-SCfRestart }
            '14' { $ShutDown = Invoke-SCfShutDown }
            '15' {
                Clear-Host
                Write-Warning -Message $StringTable.ExitMessage
                return
            }
        }
        $LaunchedAtSignIn = $false # only show warning once
    }
    while (-not $ShutDown)

    Clear-Host
}
