# PowerCLI script to create SimpliVity Virtual Networking for Storage and Federation Traffic
# Usage Prepare_OmniCube_Network.ps1 -File PathtoConfigCSV
#
# This script will ensure consistent configuration of the Storage and Federation Networks
# across all OmniCube hosts.
#
# CSV File Format/Example - First line with column names must be included.
# If StoreVMKVLANID, FedPGVLAN, or StorePGVLAN are not tagged set them to 0
#
# ESXiHostIP,Username,Password,StoreVMKIP,StoreVMKMask,StoreVMKVLANID,FedPGVLAN,StorePGVLAN,NULL 
# 192.168.1.20,root,password,192.168.10.20,255.255.255.0,10,20,10,NULL
# 192.168.1.21,root,password,192.168.10.21,255.255.255.0,10,20,10,NULL
#
# Prepare_OmniCube_Network.ps1 Vesrion History
# Version 1.0 - Hersey Cartwright - 06/10/2015
#
# To do:
#   Set active vmnic on vSwitch
#   Attempt to pull config info direct from Pre-Flight spreadsheet
#
# Edit the $FedPG, $StorePG, $StoreVMK, and $MTU variables to match the PortGroup Names 
# from the Pre-Flight Checklist
#
# Get File Path from Commandline Parameter
param(
 [string]$File
)

#Variables
#Set the following variables from the Pre-Flight
#Federation PortGroup Name
$FedPG = "FederationPG"

#Storage PortGroup Name
$StorePG = "StoragePG"

#Storage VMkernel Name
$StoreVMK = "Storage"

#Set the MTU
$MTU = "9000"

#Only change this is you are using something other than vSwitch1
$vSwitchName = "vSwitch1"

Clear-Host

$usage = "Prepare_OmniCube_Network.ps1 -File PathtoConfigCSV"
$example = 'Prepare_OmniCube_Network.ps1 -File C:\SimpliVity\Config.csv' 

Write-Host `n `n"This PowerCLI script can be used to create SimpliVity Virtual Networking" -ForeGroundColor Cyan
Write-Host "used for OmniCube Storage and SimpliVity Federation Traffic"`n -ForeGroundColor Cyan

# Test for missing File command line parameter
if ( !$File ) {
  write-host `n `n"Missing Required Parameter - Full Path to Configuration File Required." `n -ForeGroundColor Red
  write-host "Usage: $usage" `n
  write-host "Example: $example" `n
  exit
}

# Test to Ensure File Exists
$FileExists = Test-Path $File
if ($FileExists -eq $False) {
  write-host `n `n"Specified CSV File Not Found!" `n -ForeGroundColor Red
  write-host "Usage: $usage" `n
  write-host "Example: $example" `n
  exit
}

# Configure each OmniCube Host
Write-Host "Preparing OmniCube Hosts"`n -ForeGroundColor Cyan

$ConfigFile = Import-CSV $File

ForEach ($Config in $ConfigFile) {
   
   #Set variables from Config line
   $HostIP = $Config.ESXiHostIP
   $HostUser = $Config.Username
   $HostPass = $Config.Password
   $VMKIP = $Config.StoreVMKIP
   $VMKMASK = $Config.StoreVMKMask
   $VMKVLAN = $Config.StoreVMKVLANID
   $FedVLAN = $Config.FedPGVLAN
   $StoreVLAN = $Config.StorePGVLAN

   #Make sure required configuration options exist
   if ( $HostIP -and $HostUser -and $HostPass -and $VMKIP -and $VMKMASK -and $VMKVLAN -and $FedVLAN -and $StoreVLAN ) {

      Write-Host "Preparing OmniCube Host $HostIP "`n -ForeGroundColor Cyan
      Write-Host "Connecting to $HostIP with username $HostUser"`n  -ForeGroundColor Cyan
      $connecthost = Connect-VIServer -Server $HostIP -User $HostUser -Password $HostPass

      Write-Host "Creating $vSwitchName on $HostIP "`n -ForeGroundColor Cyan
      $vswitch = New-VirtualSwitch -VMHost $HostIP -Name $vSwitchName -Nic vmnic0,vmnic1 -MTU $MTU
      #$vswitch = New-VirtualSwitch -VMHost $HostIP -Name $vSwitchName -MTU $MTU #For testing - creates vswitch with no uplinks
      
      Write-Host "Creating Storage VMkernel $StoreVMK on $vSwitchName"`n -ForeGroundColor Cyan
      $storagevmkernel = New-VMHostNetworkAdapter -VirtualSwitch $vswitch -PortGroup $StoreVMK -IP $VMKIP -SubnetMask $VMKMASK -MTU $MTU -vMotionEnabled $true 

      Write-Host "Setting VLAN $VMKVLAN to on Storage VMkernel $StoreVMK"`n -ForeGroundColor Cyan
      $setvmkernelvlan = Get-VirtualPortGroup -VMHost $HostIP -Name $StoreVMK | Set-VirtualPortGroup -VLanId $VMKVLAN

      Write-Host "Creating Storage PortGroup $StorePG tagged with VLAN $StoreVLAN on $vSwitchName"`n -ForeGroundColor Cyan
      $storagepg = New-VirtualPortGroup -VirtualSwitch $vswitch -Name $StorePG -VLanId $StoreVLAN

      Write-Host "Creating Federation PortGroup $FedPG tagged with VLAN $FedVLAN on $vSwitchName"`n -ForeGroundColor Cyan
      $federationpg = New-VirtualPortGroup -VirtualSwitch $vswitch -Name $FedPG -VLanId $FedVLAN

      #Disconnect from the Host
      Write-Host "Disconnecting from Host at $HostIP "`n -ForeGroundColor Cyan
      $disconnecthost = Disconnect-VIserver -Server $HostIP -Confirm:$false

   } Else {

     write-host `n `n"Issue with line in Configuration CSV - Required parameters not found on line!" `n -ForeGroundColor Red      
     write-host "Skipping to next line in Configuration CSV." `n -ForeGroundColor Red  

   }

}

Write-Host "Preparing OmniCube Hosts Completed"`n `n -ForeGroundColor Cyan