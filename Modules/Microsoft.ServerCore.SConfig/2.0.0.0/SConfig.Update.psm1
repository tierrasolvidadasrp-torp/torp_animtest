# Set up localization
$TextModulePath = Join-Path -Path $psScriptRoot -ChildPath "\SConfig.Text.psm1"
Import-Module -Name $TextModulePath -Force
$StringTable = Get-SCfLocalizedStringTable
$SingleCharLookup = Get-SCfSingleCharLookupTable $StringTable
$StringTable = Convert-SCfAmpersandToParentheses $StringTable # Converts single-char identifier "&" to a set of parentheses around the letter

# For Invoke-SCfRestart
Import-Module -Name "$psScriptRoot\SConfig.Computer.psm1" -Force

<#
    Get the current value of the Windows Update setting
    Output: a string representation of the current value
#>
function Get-SCfUpdateSetting
{
    [CmdletBinding()]
    param()

    try
    {
        $NoAutoUpdateVal = 0 # Default in case reg value is not present
        $NoAutoUpdateVal = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue

        if ($NoAutoUpdateVal.NoAutoUpdate -eq 1)
        {
            return $StringTable.UpdateSetting_Manual
        }
        else
        {
            $AUOptionsVal = 0 # Default in case reg value is not present
            $AUOptionsVal = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'AUOptions' -ErrorAction SilentlyContinue

            switch ($AUOptionsVal.AUOptions)
            {
                3 { return $StringTable.UpdateSetting_DownloadOnly }
                4 { return $StringTable.UpdateSetting_Automatic }
                default { return $StringTable.UpdateSetting_NotConfigured }
            }
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.UpdateSetting_Status_Failed
    }
}

<#
    Interprets the result code of the update installer
    Input: a numerical result code
    Output: the corresponding status string
#>
function Get-SCfUpdateInstallerResultCodeText
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $ResultCode
    )

    switch ($ResultCode)
    {
        0 { return $StringTable.InstallUpdates_ResultCode_NotStarted }
        1 { return $StringTable.InstallUpdates_ResultCode_InProgress }
        2 { return $StringTable.InstallUpdates_ResultCode_Succeeded }
        3 { return $StringTable.InstallUpdates_ResultCode_SucceededErrors }
        4 { return $StringTable.InstallUpdates_ResultCode_Failed }
        5 { return $StringTable.InstallUpdates_ResultCode_Stopped }
    }
}

function Set-SCfPreviewChannelSetting
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $CurrentOS,

        [Parameter(Mandatory=$false)]
        [Switch]
        $DebugOutput
    )

    if (-not $DebugOutput.IsPresent) { Clear-Host }

    # Find the current previewchannel settings
    try
    {
        $PreviewChannelSettings = Get-PreviewChannel
        Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.PreviewChannel_Configure_Title)
  $($StringTable.PreviewChannel_CurrentSetting)
"@
        if (-not $PreviewChannelSettings.Enabled)
        {
            Write-SCfHost -Indent 2 -Object "$($StringTable.PreviewChannel_Status) $($StringTable.PreviewChannel_NotConfigured)"
        }
        else
        {
            $Labels = @(
                $StringTable.PreviewChannel_Status,
                $StringTable.PreviewChannel_Channel,
                $StringTable.PreviewChannel_Ring
            )
            $Padding = Get-SCfLabelPaddingArray $Labels
            Write-SCfHost -Indent 0 -Object @"
    $($StringTable.PreviewChannel_Status)$($Padding[$StringTable.PreviewChannel_Status])$($StringTable.PreviewChannel_Enabled)
    $($StringTable.PreviewChannel_Channel)$($Padding[$StringTable.PreviewChannel_Channel])$($PreviewChannelSettings.Channel)
"@
            if ($PreviewChannelSettings.Channel -ne 'ReleasePreview')
            {
                Write-SCfHost -Indent 0 -Object @"
    $($StringTable.PreviewChannel_Ring)$($Padding[$StringTable.PreviewChannel_Ring])$($PreviewChannelSettings.Ring)
"@
            }
        }

        Write-SCfHost -Indent 0
        $WrappedLines = Get-SCfWrappedText $StringTable.PreviewChannel_Change_ConfirmText
        foreach ($Line in $WrappedLines) { Write-SCfHost -Object $Line }

        # If user confirms no change required, just return
        Write-SCfHost -Indent 0
        $UserInput = Read-SCfHost -Prompt @($StringTable.PreviewChannel_Change_ConfirmText_Prompt, $StringTable.YesNoSuffix)
        if ($UserInput -ne $SingleCharLookup['YesNoSuffix'][0]) { return }

        Write-SCfHost -Indent 0 -Object @"
  $($StringTable.PreviewChannel_PickSetting)

"@
        $WrappedLines = Get-SCfWrappedText $($StringTable.PreviewChannel_MenuOptions_ReleasePreviewChannel -f $CurrentOS)
        foreach ($Line in $WrappedLines) { Write-SCfHost -Indent 2 -Object $Line }
        Write-SCfHost -Indent 0 -Object @"

    $($StringTable.PreviewChannel_MenuOptions_CustomChannel)

"@

        $InputList = $SingleCharLookup['PreviewChannel_ChannelPrompt']
        do { $SetPreviewChannelOption = Read-SCfHost -Prompt @($StringTable.PreviewChannel_ChannelPrompt, $StringTable.BlankToCancel) }
        until ($InputList -contains $SetPreviewChannelOption)

        if (-not $SetPreviewChannelOption) { return }
        switch ($SetPreviewChannelOption)
        {
            $InputList[0] { # "ReleasePreview Channel & Canary Ring"
                if ($PreviewChannelSettings.Channel -eq 'ReleasePreview')
                {
                    $PreviewResult = @{ Succeeded = $true }
                }
                else
                {
                    # Set to release preview channel (default behavior)
                    if ($PSCmdlet.ShouldProcess('ReleasePreview', 'Set-PreviewChannel'))
                    {
                        $PreviewResult = Set-PreviewChannel
                    }
                }
            }
            $InputList[1] { # "Custom Channel"
                Write-SCfHost -Indent 0
                $UserInputChannel = Read-SCfHost -Indent 2 -Prompt @($StringTable.PreviewChannel_EnterChannel, $StringTable.BlankToCancel)
                if (-not $UserInputChannel) { return }

                $Attempts = 0
                $Max = 10
                $ValidInput = $false
                while (-not ($Attempts -eq $Max -or $ValidInput))
                {
                    try
                    {
                        $Attempts++
                        $UserInputRing = Read-SCfHost -Indent 2 -Prompt @($StringTable.PreviewChannel_EnterRing, $StringTable.BlankToCancel)
                        if (-not $UserInputRing) { return }

                        if ($PSCmdlet.ShouldProcess(@($UserInputChannel, $UserInputRing), 'Set-PreviewChannel'))
                        {
                            $PreviewResult = Set-PreviewChannel -Channel $UserInputChannel -Ring $UserInputRing
                        }

                        $ValidInput = $true
                    }
                    catch [System.ArgumentException]
                    {
                        Write-SCfHost -Indent 2 -Object $_
                    }
                }
                if ($Attempts -eq $Max)
                {
                    Write-SCfHost -Indent 2 -Object $($StringTable.PreviewChannel_TooManyAttempts -f $Max)
                    Read-SCfHost -Indent 2 -Prompt $StringTable.Continue
                    return
                }
            }
        }

        if ($PreviewResult.Succeeded)
        {
            Write-SCfHost -Object $StringTable.PreviewChannel_PreviewDone
            if ($PreviewResult.RestartRequired)
            {
                Invoke-SCfRestartPrompt
            }
        }
        else
        {
            Write-SCfHost -Object "$($StringTable.PreviewChannel_Failed) ExitCode: $($PreviewResult.Exitcode)"
        }

        Read-SCfHost -Prompt $StringTable.Continue
      }
      catch
      {
          Invoke-SCfErrorHandler -Error $_
      }
}

# Set Windows Update setting based on user input: returns true if setting was changed
function Set-SCfUpdateSetting
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $CurrentOS,

        [Parameter(Mandatory=$false)]
        [Switch]
        $AllowPreviewChannelOptIn,

        [Parameter(Mandatory=$false)]
        [Switch]
        $DebugOutput
    )

    $CurrentUpdateSetting = Get-SCfUpdateSetting
    Write-SCfHost -Indent 0 -Object @"
$(Get-SCfHeader $StringTable.UpdateSetting_Title)
  $($StringTable.UpdateSetting_CurrentSetting) $($CurrentUpdateSetting)

"@


    if (-not $AllowPreviewChannelOptIn.IsPresent)
    {
        $InputList = $SingleCharLookup['UpdateSetting_SettingPrompt']
        do { $UpdateSelection = Read-SCfHost -Prompt @($StringTable.UpdateSetting_SettingPrompt, $StringTable.BlankToCancel) }
        until ($InputList -contains $UpdateSelection)
        if (-not $UpdateSelection) { return }

        # Map letter input to number for upcoming switch statement
        switch ($UpdateSelection)
        {
            $InputList[0] { $UpdateSelection = '1' }
            $InputList[1] { $UpdateSelection = '2' }
            $InputList[2] { $UpdateSelection = '3' }
        }
    }
    else
    {
        Write-SCfHost -Indent 0 -Object @"
  $($StringTable.UpdateSetting_OptionsTitle)

    1) $($StringTable.UpdateSetting_Automatic)
    2) $($StringTable.UpdateSetting_DownloadOnly)
    3) $($StringTable.UpdateSetting_Manual)

  $($StringTable.UpdateSetting_Or)

    4) $($StringTable.UpdateSetting_Preview)

"@
        $InputList = @('1', '2', '3', '4', [System.String]::Empty)
        do { $UpdateSelection = Read-SCfHost -Prompt @($StringTable.UpdateSetting_AlternateSettingPrompt, $StringTable.BlankToCancel) }
        until ($InputList -contains $UpdateSelection)
        if (-not $UpdateSelection) { return }
    }

    $UpdateSettingPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    try
    {
        switch ($UpdateSelection)
        {
            '1' { # 'Automatic'
                if ($CurrentUpdateSetting -eq $StringTable.UpdateSetting_Automatic)
                {
                    return
                }

                if (-not $(Test-Path $UpdateSettingPath) -and $PSCmdlet.ShouldProcess($UpdateSettingPath, 'New-Item'))
                {
                    New-Item $UpdateSettingPath -Force | Out-Null
                }

                if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'AUOptions', 4), 'Set-ItemProperty'))
                {
                    Set-ItemProperty -Path $UpdateSettingPath -Name AUOptions -Value 4 -Force
                }

                if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'NoAutoUpdate', 0x0), 'Set-ItemProperty'))
                {
                    Set-ItemProperty -Path $UpdateSettingPath -Name NoAutoUpdate -Value 0x0 -Force
                }
            }
            '2' { # 'DownloadOnly'
                if ($CurrentUpdateSetting -eq $StringTable.UpdateSetting_DownloadOnly)
                {
                    return
                }

                if (-not $(Test-Path $UpdateSettingPath) -and $PSCmdlet.ShouldProcess($UpdateSettingPath, 'New-Item'))
                {
                    New-Item $UpdateSettingPath -Force | Out-Null
                }

                if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'AUOptions', 3), 'Set-ItemProperty'))
                {
                    Set-ItemProperty -Path $UpdateSettingPath -Name AUOptions -Value 3 -Force
                }

                if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'NoAutoUpdate', 0x0), 'Set-ItemProperty'))
                {
                    Set-ItemProperty -Path $UpdateSettingPath -Name NoAutoUpdate -Value 0x0 -Force
                }
            }
            '3' { # 'Manual'
                if ($CurrentUpdateSetting -eq $StringTable.UpdateSetting_Manual)
                {
                    return
                }

                if (Test-Path $UpdateSettingPath) {
                    if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'NoAutoUpdate', 0x1), 'Set-ItemProperty'))
                    {
                        Set-ItemProperty -Path $UpdateSettingPath -Name NoAutoUpdate -Value 0x1 -Force
                    }

                    if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'AUOptions'), 'Remove-ItemProperty'))
                    {
                        Remove-ItemProperty -Path $UpdateSettingPath -Name AUOptions -ErrorAction SilentlyContinue
                    }
                }
                else
                {
                    if ($PSCmdlet.ShouldProcess($UpdateSettingPath, 'New-Item'))
                    {
                        New-Item $UpdateSettingPath -Force  | Out-Null
                    }

                    if ($PSCmdlet.ShouldProcess(@($UpdateSettingPath, 'NoAutoUpdate', 0x1), 'New-ItemProperty'))
                    {
                        New-ItemProperty -Path $UpdateSettingPath -Name NoAutoUpdate -Value 0x1 -Force  | Out-Null
                    }
                }
            }
            '4' { # PreviewChannel
                Set-SCfPreviewChannelSetting -CurrentOS $CurrentOS -DebugOutput:$($DebugOutput.IsPresent)
            }
        }

        if ($UpdateSelection -ne '4')
        {
            Write-SCfHost -Object $StringTable.UpdateSetting_Success
            Read-SCfHost -Prompt $StringTable.Continue
        }
        return $true
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_ -Message $StringTable.UpdateSetting_Failed
    }
}

<#
    Remove feature updates from a collection of updates
    Inputs:
        Updates: collection of update objects
        ReturnHiddenUpdates: switch that indicates the "hidden" feature updates are returned instead of the input collection
    Output: Either the input collection with the feature updates removed, or the feature updates that were removed
#>
function Hide-SCfFeatureUpdate
{
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateList,

        [Parameter(Mandatory=$false)]
        [Switch]
        $ReturnHiddenUpdates
    )

    $Filtered = @()
    $Hidden = @()
    $FeatureUpdateFlag = $false

    foreach ($Update in $UpdateList)
    {
        $Categories = $Update.Categories
        foreach ($Category in $Categories)
        {
            if ($Category.CategoryID -eq '3689BDC8-B205-4AF4-8D4A-A63924C5E9D5')
            {
                $FeatureUpdateFlag = $true
                $Hidden += $Update
            }
        }

        if (-not $FeatureUpdateFlag)
        {
            $Filtered += $Update
        }
        else
        {
            # Reset flag for next update to scan
            $FeatureUpdateFlag = $false
        }
    }

    if ($ReturnHiddenUpdates) { return $Hidden }
    else { return $Filtered }
}

<#
    Get the feature update out of a set of updates
    Input: collection of Updates
    Output: the feature update in the collection, if it exists
#>
function Select-SCfFeatureUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateList
    )

    return Hide-SCfFeatureUpdate -UpdateList $UpdateList -ReturnHiddenUpdates
}

<#
    Searches for update based on selected category, returns update information
    Inputs:
        UpdateSession: the current Microsoft.Update.Session com Object
        Inputs: possible inputs for search Prompt
        Selection: selection out of the given Inputs
    Output: collection of updates found through search
#>
function Search-SCfUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateSession,

        [Parameter(Mandatory=$true)]
        $Selection
    )

    try
    {
        $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
        $SearchCriteriaAllUpdates = "IsInstalled=0 and DeploymentAction='Installation' or
                                     IsInstalled=0 and DeploymentAction='OptionalInstallation' or
                                     IsPresent=1 and DeploymentAction='Uninstallation' or
                                     IsInstalled=1 and DeploymentAction='Installation' and RebootRequired=1 or
                                     IsInstalled=0 and DeploymentAction='Uninstallation' and RebootRequired=1"
        $SearchCriteriaRecommended = "IsInstalled=0 and Type='Software' and AutoSelectOnWebsites=1"

        switch ($Selection)
        {
            '1' { # 'All'
                Write-SCfHost -Object $StringTable.InstallUpdates_SearchingAll
                $SearchResult = $UpdateSearcher.Search($SearchCriteriaAllUpdates)
                $UpdateList = Hide-SCfFeatureUpdate $SearchResult.Updates
            }
            '2' { # 'Recommended'
                Write-SCfHost -Object $StringTable.InstallUpdates_SearchingRecommended
                $SearchResult = $UpdateSearcher.Search($SearchCriteriaRecommended)
                $UpdateList = Hide-SCfFeatureUpdate $SearchResult.Updates
            }
            '3' { # 'Feature'
                Write-SCfHost -Object $StringTable.InstallUpdates_SearchingFeature
                $SearchResult = $UpdateSearcher.Search($SearchCriteriaAllUpdates)
                $UpdateList = Select-SCfFeatureUpdate -UpdateList $SearchResult.Updates
            }
        }

        return $UpdateList
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_
    }
}

<#
    Downloads selected update(s)
    Inputs:
        UpdateSession: the current Microsoft.Update.Session com Object
        Updates: collection of updates found from search
        UpdateIndex: index of the update to install (-1 for 'all')
#>
function Invoke-SCfDownloadUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateSession,

        [Parameter(Mandatory=$true)]
        $UpdateList,

        [Parameter(Mandatory=$true)]
        $UpdateIndex
    )

    $UpdatesToDownload = New-Object -Com Microsoft.Update.UpdateColl
    for ($Count = 0; $Count -lt $UpdateList.Count; $Count++)
    {
        if ($UpdateIndex -eq -1)
        {
            $Update = $UpdateList.Item($Count)
            $Null = $UpdatesToDownload.Add($Update)
        }
        elseif ($Count -eq ($UpdateIndex - 1))
        {
            $Update = $UpdateList.Item($Count)
            $Null = $UpdatesToDownload.Add($Update)
        }
    }

    Write-SCfHost -Object $StringTable.InstallUpdates_Downloading
    $Downloader = $UpdateSession.CreateUpdateDownloader()
    $Downloader.Updates = $UpdatesToDownload
    $Null = $Downloader.Download()
}

<#
    Installs selected update(s)
    Inputs:
        UpdateSession: the current Microsoft.Update.Session com Object
        Updates: collection of updates found from search
        UpdateIndex: index of the update to install (-1 for 'all')
    Output: InstallationResult object
#>
function Invoke-SCfInstallSelectedUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateSession,

        [Parameter(Mandatory=$true)]
        $UpdateList,

        [Parameter(Mandatory=$true)]
        $UpdateIndex
    )

    $UpdatesToInstall = New-Object -Com Microsoft.Update.UpdateColl

    if ($UpdateIndex -ne -1)
    {
        $Update = $UpdateList.Item($UpdateIndex - 1)
        if ($Update.IsDownloaded)
        {
            $Null = $UpdatesToInstall.Add($Update)
        }
    }
    else
    {
        for ($Count = 0; $Count -lt $UpdateList.Count; $Count++)
        {
            $Update = $UpdateList.Item($Count)
            if ($Update.IsDownloaded)
            {
                $Null = $UpdatesToInstall.Add($Update)
            }
        }
    }

    Write-SCfHost -Object $StringTable.InstallUpdates_Installing
    $Installer = $UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()

    Write-SCfHost -Indent 0
    Write-SCfHost -Object $StringTable.InstallUpdates_InstallResults
    for ($Count = 0; $Count -lt $UpdatesToInstall.Count; $Count++)
    {
        $ResultCodeText = Get-SCfUpdateInstallerResultCodeText -resultcode $InstallationResult.GetUpdateResult($Count).ResultCode;
        $Parameters = @{
            Indent = 2
            Object = $(($Count + 1).ToString()  + ') ' + $ResultCodeText + ' - ' + $UpdatesToInstall.Item($Count).Title)
        }
        Write-SCfHost @Parameters
    }

    $ResultCodeText = Get-SCfUpdateInstallerResultCodeText -resultcode $InstallationResult.ResultCode;
    Write-SCfHost -Indent 0 -Object @"

  $($StringTable.InstallUpdates_InstallSummary)
    $($StringTable.InstallUpdates_Result + ': ' + $ResultCodeText)
    $($StringTable.InstallUpdates_Restart + ': ' + $InstallationResult.RebootRequired)

"@

    return $InstallationResult
}

<#
    Guides the user through a feature update
    Inputs:
        UpdateSession: the current Microsoft.Update.Session com Object
        Updates: collection of updates found from search
#>
function Invoke-SCfFeatureUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateSession,

        [Parameter(Mandatory=$true)]
        $UpdateList,

        [Parameter(Mandatory=$true)]
        $FeatureUpdateVersion
    )

    try
    {
        Write-SCfHost -Indent 0 -Object $(Get-SCfHeader $StringTable.InstallUpdates_FeatureUpdate_Title)

        $Sorted = Sort-Object -Input $UpdateList -Property LastDeploymentChangeTime
        $Update = $Sorted[0]

        Write-SCfHost -Indent 0 -Object @"
  $($StringTable.InstallUpdates_FeatureUpdateLabel)

    $($Update.Title)

"@
        $WrappedLines = Get-SCfWrappedText $StringTable.InstallUpdates_FeatureUpdate_Description
        foreach ($Line in $WrappedLines) { Write-SCfHost -Object $Line  }
        Write-SCfHost -Indent 0

        if ($FeatureUpdateVersion -eq 1) {
            $WarningText = $StringTable.InstallUpdates_FeatureUpdate_Warning
        }
        if ($FeatureUpdateVersion -eq 2) {
            $WarningText = $StringTable.InstallUpdates_FeatureUpdate_ImportantInformation
        }
        $WrappedLines = Get-SCfWrappedText $WarningText
        foreach ($Line in $WrappedLines) { Write-SCfHost -Object $Line  }
        Write-SCfHost -Indent 0

        $Install = Read-SCfHost -Prompt @($StringTable.InstallUpdates_FeatureUpdate_InstallPrompt, $StringTable.YesNoSuffix)
        if ($Install -ne $SingleCharLookup['YesNoSuffix'][0]) { return }

        $UpdatesCollection = New-Object -Com Microsoft.Update.UpdateColl

        # Download
        Write-SCfHost -Object $StringTable.InstallUpdates_Downloading
        $UpdatesCollection.Add($Update) | Out-Null
        $Downloader = $UpdateSession.CreateUpdateDownloader()
        $Downloader.Updates = $UpdatesCollection
        $DownloadResult = $Downloader.Download()

        if ($DownloadResult.ResultCode -ne 2) # If not 'Succeeded'
        {
            Read-SCfHost -Prompt @($StringTable.InstallUpdates_ResultLabel, $(Get-SCfUpdateInstallerResultCodeText $DownloadResult.ResultCode), $StringTable.Continue)
            return
        }


        # Install
        Write-SCfHost -Object $StringTable.InstallUpdates_Installing
        $Installer = $UpdateSession.CreateUpdateInstaller()
        $Installer.Updates = $UpdatesCollection
        $InstallationResult = $Installer.Install()

        if ($InstallationResult.ResultCode -ne 2) # If not 'Succeeded'
        {
            Read-SCfHost -Prompt @($StringTable.InstallUpdates_ResultLabel, $(Get-SCfUpdateInstallerResultCodeText $InstallationResult.ResultCode), $StringTable.Continue)
            return
        }

        #Commit
        $Committer = $UpdateSession.CreateUpdateInstaller()
        $Committer.Updates = $UpdatesCollection
        $Committer.Commit(0)
        Restart-Computer

        return
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_
    }
}

<#
    Guides the user through quality updates
    Inputs:
        UpdateSession: the current Microsoft.Update.Session com Object
        Updates: collection of updates found from search
#>
function Invoke-SCfQualityUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $UpdateSession,

        [Parameter(Mandatory=$true)]
        $UpdateList
    )

    try
    {
        # Select updates to install
        Write-SCfHost -Indent 0
        Write-SCfHost -Object $StringTable.InstallUpdates_AvailableUpdates

        if (-not $UpdateList.Count) # Single update
        {
            Write-SCfHost -Indent 0
            Write-SCfHost -Indent 2 -Object "1) $($UpdateList.Title)"
        }
        else
        {
            for ($Count = 0; $Count -lt $UpdateList.Count; $Count++)
            {
                $Update = $UpdateList.Item($Count)
                $Parameters = @{
                    Indent = 2
                    Object = $(($Count + 1).ToString()  + ') ' + $Update.Title)
                }
                Write-SCfHost @Parameters
            }
        }

        Write-SCfHost -Indent 0
        $UpdateIndex = -1

        if ($UpdateList.Count -eq 1) # If only one update available
        {
            $Install = Read-SCfHost -Prompt @($StringTable.InstallUpdates_InstallSingle, $StringTable.YesNoSuffix)
            if ($Install -ne $SingleCharLookup['YesNoSuffix'][0]) { return }
        }
        else
        {
            $InputList = $SingleCharLookup['InstallUpdates_SelectOptions']
            do { $UpdateSelection = Read-SCfHost -Prompt @($StringTable.InstallUpdates_SelectOptions, $StringTable.BlankToCancel) }
            until ($InputList -contains $UpdateSelection)

            if (-not $UpdateSelection)
            {
                return
            }
            elseif ($UpdateSelection -eq $InputList[1]) # 'No'
            {
                return
            }
            elseif ($UpdateSelection -eq $InputList[2]) # 'Single'
            {
                do
                {
                    $UpdateIndex = Read-SCfHost -Prompt @($StringTable.InstallUpdates_NumberPrompt, $StringTable.BlankToCancel)
                    if (-not $UpdateIndex) { return }
                }
                while (-not ($UpdateIndex -match '^\d+$') -or $UpdateIndex -le 0 -or $UpdateIndex -gt $UpdateList.Count)
            }
        }

        # Download and install updates
        $Parameters = @{
            UpdateSession = $UpdateSession
            UpdateList    = $UpdateList
            UpdateIndex   = $UpdateIndex
        }
        Invoke-SCfDownloadUpdate @Parameters
        $InstallationResult = Invoke-SCfInstallSelectedUpdate @Parameters

        if ($InstallationResult.RebootRequired -eq $true)
        {
            Invoke-SCfRestartPrompt
        }
        else
        {
            Read-SCfHost -Prompt $StringTable.Continue
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_
    }
}

# Guide the user through downloading and installing updates
function Invoke-SCfInstallUpdate
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $IsElevatedSession,

        [Parameter(Mandatory=$false)]
        $FeatureUpdateVersion,

        [Parameter(Mandatory=$false)]
        [Switch]
        $DebugOutput
    )

    Write-SCfHost -Indent 0 -Object $(Get-SCfHeader $StringTable.InstallUpdates_Title)

    try
    {
        $UpdateSession = New-Object -Com Microsoft.Update.Session
        $UpdateSession.ClientApplicationID = 'SConfig'

        $Selection = [System.String]::Empty
        if ($FeatureUpdateVersion -eq 0)
        {
            $InputList = $SingleCharLookup['InstallUpdates_SearchPrompt']
            do { $Selection = Read-SCfHost -Prompt @($StringTable.InstallUpdates_SearchPrompt, $StringTable.BlankToCancel) }
            until ($InputList -contains $Selection)
            if (-not $Selection) { return }

            # Map letter input to number for upcoming switch statement
            switch ($Selection)
            {
                $InputList[0] { $Selection = '1' }
                $InputList[1] { $Selection = '2' }
            }
        }
        else
        {
            Write-SCfHost -Indent 0 -Object @"
  $($StringTable.InstallUpdates_SearchHeader)

    1) $($StringTable.InstallUpdates_Option_All)
    2) $($StringTable.InstallUpdates_Option_Recommended)
    3) $($StringTable.InstallUpdates_Option_Feature)

"@
            # Prompt for update category
            $InputList = @('1', '2', '3', [String]::Empty)
            do { $Selection = Read-SCfHost -Prompt @($StringTable.InstallUpdates_CategoryPrompt, $StringTable.BlankToCancel) }
            until ($InputList -contains $Selection)
            if (-not $Selection) { return }
        }


        $UpdateList = Search-SCfUpdate $UpdateSession $Selection
        if ($UpdateList.Count -eq 0)
        {
            Write-SCfHost -Object $StringTable.InstallUpdates_NoUpdates
            Read-SCfHost -Prompt $StringTable.Continue
            return
        }
        elseif (-not $UpdateList.Count)
        {
            $UpdateList = @($UpdateList)
        }

        # Feature updates have a different logic than quality updates
        if ($Selection -eq $InputList[2])
        {
            if (-not $DebugOutput.IsPresent) { Clear-Host }
            Invoke-SCfFeatureUpdate $UpdateSession $UpdateList $FeatureUpdateVersion
        }
        else
        {
            Invoke-SCfQualityUpdate $UpdateSession $UpdateList
        }
    }
    catch [System.Runtime.InteropServices.COMException]
    {
        if ((-not $IsElevatedSession) -and $_ -like '*0x80240024*')
        {
            Invoke-SCfErrorHandler -Error $_ -Message $StringTable.InstallUpdates_FailedElevation
        }
        else
        {
            throw
        }
    }
    catch
    {
        Invoke-SCfErrorHandler -Error $_
    }
}

Export-ModuleMember -Function *
