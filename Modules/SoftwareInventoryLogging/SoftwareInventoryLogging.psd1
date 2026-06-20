@{

#
# Module manifest for module 'SoftwareInventoryLogging'
#

# Version number of this module.
ModuleVersion = '2.0.0.0'

# ID used to uniquely identify this module
GUID = '{421a5b89-0f16-4df7-b607-fffd66107510}'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '© Microsoft Corporation. All rights reserved.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Nested modules associated with this manifest
NestedModules = @(
    'MsftSil_Computer.cdxml',
    'MsftSil_ComputerIdentity.cdxml',
    'MsftSil_Software.cdxml',
    'MsftSil_WindowsUpdate.cdxml',
    'MsftSil_UalAccess.cdxml',
    'MsftSil_Data.cdxml',
    'MsftSil_ManagementTasks.psm1',
    'Msft_MiStreamTasks.cdxml'
)

TypesToProcess = @('SoftwareInventoryLogging.Types.ps1xml')
FormatsToProcess = @('SoftwareInventoryLogging.Format.ps1xml')

# Functions to export from this module
FunctionsToExport = @(
    'Get-SilComputer',
    'Get-SilComputerIdentity',
    'Get-SilSoftware',
    'Get-SilWindowsUpdate',
    'Get-SilUalAccess',
    'Get-SilLogging',
    'Set-SilLogging',
    'Start-SilLogging',
    'Stop-SilLogging'
    'Get-SilData',
    'Publish-SilData'
)

# HelpInfo URI of this module
HelpInfoUri = 'https://aka.ms/winsvr-2022-pshelp'

CompatiblePSEditions = @('Desktop','Core')
}
