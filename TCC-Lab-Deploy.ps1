
########################################################################################################
# PowerCLI script to Deploy TCC VMware IT Academy Labs for ITN254/ITN255/ITN231 from Master vApp
# Usage TCC-Lab-Deploy.ps1
#
# Distributes vApps across available hosts
# Creates Isolated vSwitch
# Creates Promiscuous Mode PortGroup
# Creates Standard PortGroup
# Clones Master vApp
# Attaches VM Network Adapters to Correct Port Groups
#
# Requires active connection to vCenter Server (using Connect-VIServer)
#
# History:
# 12/11/2015 - Hersey http://www.vhersey.com/ - Created
#
########################################################################################################

############Lab Variables##########################
#Cluster Name
$ClusterName = "LABCLUSTER"

#Master vApp
$MastervApp = "Test"

#Datastore
$Datastore = "NFS_Datastore1"

#SetvApp Prefix
$vAppPrefix = "LAB"

#ClassRoom PortGroup
$ClassRoomPG = "ClassRoom"

#Master vApp Promiscuous Mode PortGroup
$vAppPMNetwork = "MasterPM"

#Master vApp Standard PortGroup
$vAppStdNetwork = "Master"

#Number of Labs to Deploy
$numlabs = "1"

##################################################
#Set Counters
$pick = 0

#Get Datastore for vApp Deployment
$vAppDatastore = Get-Datastore -Name $Datastore

#Get Hosts available for vApp Deployment
$Hosts = Get-VMHost -Location $ClusterName
$numhost = $Hosts.Count

Write-Host "Deploying Lab Across $NumHosts Hosts"

Foreach ( $_ in 1..$numlabs ) {

  $lab++
  
  If ( $pick -eq $numhost -Or $pick -gt $numhost ) {
     Write-Host "Reseting PickHost"
     $pick = 0
  }

  $DeployHost = $Hosts[$pick]
  Write-Host "Pick: $pick"
  Write-Host "Deploy on Host: $DeployHost"
  Write-Host "Lab: $lab"
  
  $LabName = "$vAppPrefix-$lab"

  #Create Isolated Lab vSwitch
  $PMPGName = "$LabName-PM"
  Write-Host "Creating $LabName vSwitch"
  $vSwitch = New-VirtualSwitch -VMHost $DeployHost -Name $LabName
  
  #Create Promiscuous Mode PortGroup
  Write-Host "Creating Promiscuous Mode PortGroup $PMPGName on vSwitch $LabName"
  $vAppPMPG = New-VirtualPortGroup -Name $PMPGName -VirtualSwitch $vSwitch
  
  #Set Promiscuous Mode on PortGroup
  Write-Host "Setting Promiscuous Mode PortGroup $PMPGName on vSwitch $LabName"
  Get-VirtualPortGroup -VirtualSwitch $vSwitch -Name $PMPGName  | Get-SecurityPolicy | Set-SecurityPolicy -AllowPromiscuous $true
  
  #Create Non-Promiscuous Mode Port Group
  Write-Host "Creating PortGroup $LabName on vSwitch $LabName"
  $vAppPG = New-VirtualPortGroup -Name $LabName -VirtualSwitch $vSwitch

  Write-Host "Deploying $LabName"
  New-vApp -VApp $MastervApp -Name $LabName -Location $Hosts[$pick] -VMHost $Hosts[$pick] -Datastore $vAppDatastore
  
  #Connect VM Network Adapters to Correct PortGroups  
  $vAppVMs = Get-VApp $LabName | Get-VM
  ForEach ($vAppVM in $vAppVMs ) {

    Get-VM -Location $LabName $vAppVM | Get-NetworkAdapter | Where {$_.NetworkName -eq $vAppPMNetwork}  | Set-NetworkAdapter -Portgroup $vAppPMPG -Confirm:$false
    Get-VM -Location $LabName $vAppVM | Get-NetworkAdapter | Where {$_.NetworkName -eq $vAppStdNetwork}  | Set-NetworkAdapter -Portgroup $vAppPG -Confirm:$false

  }
 
  $pick++

}
