function Invoke-SilMethod
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $MethodName,

        [Hashtable]
        $Arguments,

        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    $methodParameters = New-Object System.Collections.Hashtable $PSBoundParameters
    $methodParameters.Namespace = 'root/inventorylogging'
    $methodParameters.ClassName = 'MsftSil_ManagementTasks'
    $methodParameters.MethodName = $MethodName
    $methodParameters.Arguments = $Arguments
    $result = Invoke-CimMethod @methodParameters -Confirm:$false -ErrorAction Stop
    return $result
}

function Start-SilLogging
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param
    (
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    $cimSessionParameter = @{}
    if ($PSBoundParameters.ContainsKey('CimSession'))
    {
        $cimSessionParameter.CimSession = $CimSession
    }

    $targetName = $CimSession.ComputerName
    if (-not $targetName) {
        $targetName = $env:COMPUTERNAME
    }

    $methodName = 'SetLoggingState'
    if ($PSCmdlet.ShouldProcess($targetName, $methodName))
    {
        $result = Invoke-SilMethod -MethodName $methodName -Arguments @{state = [byte]1} @cimSessionParameter
    }
}

function Stop-SilLogging
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param
    (
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    $cimSessionParameter = @{}
    if ($PSBoundParameters.ContainsKey('CimSession'))
    {
        $cimSessionParameter.CimSession = $CimSession
    }

    $targetName = $CimSession.ComputerName
    if (-not $targetName) {
        $targetName = $env:COMPUTERNAME
    }

    $methodName = 'SetLoggingState'
    if ($PSCmdlet.ShouldProcess($targetName, $methodName))
    {
        $result = Invoke-SilMethod -MethodName $methodName -Arguments @{state = [byte]0} @cimSessionParameter
    }
}

function Get-SilLogging
{
    [CmdletBinding()]
    param
    (
        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    $CimSession | % {
        $cimSessionParameter = @{}
        $computerName = $null
        if ($_)
        {
            $cimSessionParameter.CimSession = $_
            $computerName = $_.ComputerName
        }
        $loggingState = Invoke-SilMethod -Method 'GetLoggingState' @cimSessionParameter
        if ($loggingState.state) {
            $state = "Running"
        } else {
            $state = "Stopped"
        }
        $loggingTime = Invoke-SilMethod -Method 'GetLoggingTime' @cimSessionParameter
        $publishSettings = Invoke-SilMethod -Method 'GetTargetUri' @cimSessionParameter
        $uri = $publishSettings.uri
        $certificateThumbprint = $publishSettings.certificateThumbprint
        [PSCustomObject]@{
            State = $state
            TimeOfDay = $loggingTime.time
            TargetUri = $publishSettings.uri
            CertificateThumbprint = $publishSettings.certificateThumbprint
            PSComputerName = $computerName
        }
    }
}

function Set-SilLogging
{
    [CmdletBinding(DefaultParameterSetName = 'TimeOfDay', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param
    (
        [Parameter(ParameterSetName = 'TimeOfDay', Mandatory = $true)]
        [Parameter(ParameterSetName = 'TargetUri')]
        [DateTime]
        $TimeOfDay,

        [Parameter(ParameterSetName = 'TargetUri')]
        [string]
        $TargetUri,

        [Parameter(ParameterSetName = 'TargetUri')]
        [string]
        $CertificateThumbprint,

        [ValidateNotNullOrEmpty()]
        [Microsoft.Management.Infrastructure.CimSession[]]
        $CimSession
    )

    $cimSessionParameter = @{}
    if ($PSBoundParameters.ContainsKey('CimSession'))
    {
        $cimSessionParameter.CimSession = $CimSession
    }

    $targetName = $CimSession.ComputerName
    if (-not $targetName) {
        $targetName = $env:COMPUTERNAME
    }

    if ($PSBoundParameters.ContainsKey('TimeOfDay'))
    {
        $methodName = 'SetLoggingTime'
        if ($PSCmdlet.ShouldProcess($targetName, $methodName))
        {
            $loggingTimes = Invoke-SilMethod -MethodName $methodName -Arguments @{time = $TimeOfDay} @cimSessionParameter
        }
    }

    $publishSettingsParameters = @{}
    if ($PSBoundParameters.ContainsKey('TargetUri'))
    {
        $publishSettingsParameters.uri = $TargetUri
    }

    if ($PSBoundParameters.ContainsKey('CertificateThumbprint'))
    {
        $publishSettingsParameters.certificateThumbprint = $CertificateThumbprint
    }

    if ($publishSettingsParameters.Count)
    {
        $methodName = 'SetTargetUri'
        if ($PSCmdlet.ShouldProcess($targetName, $methodName))
        {
            $publishSettings = Invoke-SilMethod -MethodName $methodName -Arguments $publishSettingsParameters @cimSessionParameter
        }
    }
}
