#######################################
# PowerCLI to start|stop TSM-SSH Service on all ESXi hosts in vCenter Inventory
# 
# Script: togglessh.ps1
# Usage: togglessh.ps1 (start|stop)
#
# History:
# 8/15/2015 - Hersey http://www.vhersey.com/ - Created
#
###############VARIABLES###############
# vCenter Server IP or FQDN
$vcenter = "192.168.1.27"
##############NO CHANGES BEYOND THIS POINT##############
#Get the commnad line arguments
$state = $args

#Make sure start or stop was passed as command line argument
if ($state -eq "start" -or $state -eq "stop") {
  #Connect to vCenter Server - Will prompt for username and password
  Write-Host "Connecting to vCenter at $vcenter"
  Connect-VIServer $vcenter | Out-Null

  Write-Host "$state TSM-SSH Service on all hosts in vCenter Inventory"

  #Get all hosts in vCenter Inventory
  $vmhosts = Get-VMHost

  foreach ($vmhost in $vmhosts) {

    if ($state -eq "start") {
      Write-Host "Starting TSM-SSH Service on $vmhost"
      Get-VMHostService -VMHost $vmhost | Where {$_.Key -eq "TSM-SSH"} | Start-VMHostService -Confirm:$false | Out-Null
    }  

    if ($state -eq "stop") {
      Write-Host "Stopping TSM-SSH Service on $vmhost"
      $stopping = Get-VMHostService -VMHost $vmhost | Where {$_.Key -eq "TSM-SSH"} | Stop-VMHostService -Confirm:$false | Out-Null
    }

  $running = (get-vmhost -Name 192.168.1.25 | Get-VMHostService | Where {$_.Key -eq "TSM-SSH"}).Running
  Write-Host "TSM-SSH Service on $vmhost Running State is now: $running"

  }

  Write-Host "All Done! Disconnecting from vCenter Server"
  Disconnect-VIServer -Confirm:$false

} else {

  Write-Host "$state is not a valid argument!"
  Write-Host "Usage: togglessh.ps1 (start|stop)"
  Write-Host "Example: togglessh.ps1 start"

}
