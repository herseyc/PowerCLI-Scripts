
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

Promiscuous Mode PortGroup"
        Get-VM -Location $LabName $vAppVM | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $vAppPMPG -Confirm:$false
     } Else {
        Write-Host "Connecting Server: $vAppVM to Standard PortGroup"
        Get-VM -Location $LabName $vAppVM | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup $vAppPG -Confirm:$false
     } 
  }
 
  $pick++

}
