# PowerCLI script to create SimpliVity Role which includes required permissions
# and assign Simplivity Service Account to Role
# Usage Create_SimpliVity_Role.ps1 -vCenter vCenterFQDNorIP -Username ServiceAccountName -Domain AuthenticationDomain

# Get Commandline Parameters - All are required
param(
 [string]$vCenter,
 [string]$Username,
 [string]$Domain
)

clear-host

$usage = "Create_SimpliVity_Role.ps1 -vCenter vCenterFQDNorIP -Username SimpliVityServiceAccountName -Domain AuthenticationDomain"
$example = 'Create_SimpliVity_Role.ps1 -vCenter "vcenter.acme.local" -Username svtuser -Domain acme' 

Write-Host "PowerCLI script to create SimpliVity Role which includes required privileges and assigns the Simplivity Service Account to Role" -ForeGroundColor Cyan 

if ( !$vCenter -or !$Username -or !$Domain ) {
  write-host `n `n"Missing Required Parameter - vCenter, Username, and Domain are required." `n -ForeGroundColor Red
  write-host "Usage: $usage" `n
  write-host "Example: $example" `n
  exit
}
 
$vCenterFQDN = $vCenter

# SimpliVity Service Account User
#The SimpliVity User account is a non-login, privileged, vCenter Server account that you specify during deployment. OmniCube uses this account to execute privileged tasks. 
$SimpliVity_User = "$Domain\$Username"

# SimpliVity Role Name
$SimpliVity_Role = "SimpliVity"

#Privileges to assign to role
#See the SimpliVity OmniCube Administrators Guide for Required Permissions
$SimpliVity_Privileges = @(
'Alarm.Create',
'Alarm.DisableActions',
'Alarm.Edit',
'Alarm.SetStatus',
'Alarm.Delete',
'Extension.Register',
'Extension.Update',
'Extension.Unregister',
'Global.Health',
'Global.LogEvent',
'Global.ManageCustomFields',
'Global.SetCustomField',
'Global.Diagnostics',
'Host.Cim.CimInteraction',
'Task.Create',
'Task.Update',
'VApp.AssignVApp',
'VApp.Unregister',
'VApp.ApplicationConfig',
'VirtualMachine.Config.ManagedBy',
'VirtualMachine.Config.Settings',
'VirtualMachine.State.RemoveSnapshot',
'VirtualMachine.State.CreateSnapshot')

Write-Host "Connecting to vCenter at $vCenterFQDN"`n -ForeGroundColor Cyan
Connect-VIServer $vCenterFQDN | Out-Null


Write-Host "Create New $SimpliVity_Role Role"`n -ForeGroundColor Cyan 
New-VIRole -Name $SimpliVity_Role -Privilege (Get-VIPrivilege -id $SimpliVity_Privileges) | Out-Null

Write-Host "Set Permissions for $SimpliVity_User using the new $SimpliVity_Role Role"`n -ForeGroundColor Cyan
#Get the Root Folder
$rootFolder = Get-Folder -NoRecursion
#Create the Permission
New-VIPermission -Entity $rootFolder -Principal $SimpliVity_User -Role "SimpliVity" -Propagate:$true | Out-Null

#Disconnect from the vCenter Server
Write-Host "Disconnecting from vCenter at $vCenterFQDN"`n -ForeGroundColor Cyan
Disconnect-VIServer $vCenterFQDN -Confirm:$false