
@{
    GUID = 'E507509A-EB81-4AF2-A141-B50CB24000F0'
    Author = 'Microsoft Corporation'
    CompanyName = 'Microsoft Corporation'
    Copyright = '© Microsoft Corporation. All rights reserved.'
    FormatsToProcess = 'UserAccessLogging.format.ps1xml'
    NestedModules = @('MsftUal_Dns.cdxml', 'MsftUal_Overview.cdxml', 'MsftUal_DeviceAccess.cdxml', 'MsftUal_UserAccess.cdxml', 'MsftUal_Admin.cdxml', 'MsftUal_DailyUserAccess.cdxml', 'MsftUal_ServerUser.cdxml', 'MsftUal_ServerDevice.cdxml', 'MsftUal_DailyDeviceAccess.cdxml', 'MsftUal_DailyAccess.cdxml', 'MsftUal_SystemId.cdxml', 'MsftUal_HyperV.cdxml')
    TypesToProcess = @()
    ModuleVersion = '1.0.0.0'
    AliasesToExport = @()
    FunctionsToExport = @('Enable-Ual', 'Disable-Ual', 'Get-Ual', 'Get-UalDns', 'Get-UalOverview', 'Get-UalDeviceAccess', 'Get-UalDailyDeviceAccess', 'Get-UalDailyAccess', 'Get-UalUserAccess', 'Get-UalDailyUserAccess', 'Get-UalHyperV', 'Get-UalServerDevice', 'Get-UalServerUser', 'Get-UalSystemId')
    PowerShellVersion = '3.0'
    CmdletsToExport = @()
    HelpInfoUri = 'https://aka.ms/winsvr-2022-pshelp'
}

