@{
GUID = '{961eaf2b-70de-4ef4-801e-bd1ea302bede}'
Author = 'Microsoft Corporation'
CompanyName = 'Microsoft Corporation'
Copyright = '© Microsoft Corporation. All rights reserved.'
ModuleVersion = '2.0.0.0'
PowerShellVersion = '4.0'
RootModule = 'SConfig.psm1'
NestedModules = @(
    'SConfig.Computer.psm1',
    'SConfig.Network.psm1',
    'SConfig.Remote.psm1',
    'SConfig.Text.psm1',
    'SConfig.Update.psm1'
)
FunctionsToExport = @(
    'Invoke-SConfig',
    'Invoke-SConfigLogon',
    'Get-SConfig',
    'Set-SConfig',
    'Reset-SConfig'
)
AliasesToExport = @('SConfig')
HelpInfoURI = 'https://aka.ms/winsvr-2022-pshelp'
}
