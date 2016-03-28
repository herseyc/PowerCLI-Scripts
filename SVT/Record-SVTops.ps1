####################################################################################
# Gets Information about the number of SimpliVity Rapid Clones and Manual Backups
# Writes counts for SimpliVity clones to $clonefile
# Writes counts for SimpliVity Backups to $backupfile
#
# Usage: Record-SVTops.ps1 -VCENTER <vcenterfqdn_or_ip> -USER <username> -PASS <password>
#
# 03/26/2016 - Version 1.3 - http://www.vhersey.com/
#
#
####################################################################################
# Get Command Line Parameters -VCENTER -USER -PASS
param(
 [Parameter(Mandatory=$true, HelpMessage=”vCenter Server”)][string]$VCENTER,
 [Parameter(Mandatory=$true, HelpMessage=”Username”)][string]$USER,
 [Parameter(Mandatory=$true, HelpMessage=”Password”)][string]$PASS
)
Write-Host "Record-SVTops.ps1 Version 1.3"

# File Paths
$topfilepath = "W:\Hersey-Scripts\count\"
$backupfile = $topfilepath + "$VCENTER.SVTbu.txt"
$clonefile = $topfilepath + "$VCENTER.SVTclone.txt"

# Times
$setDays = -2 # Number of days to go back for initial counts
$setMinutes = -6 # Number of minutes to go back in events after initial
$setSeconds = 300 # Number of seconds to sleep for loop

# Connect ot VCENTER server using USER and PASS
Write-Host "Connecting to $VCENTER as $USER"
Connect-VIServer -Server $VCENTER -User $USER -Password $PASS 

# If either file does not exist, create new with counts from last $setDays
If (!(Test-Path $clonefile) -Or !(Test-Path $backupfile)) {

   $countSVTclones = 0
   $countSVTbu = 0
   Write-Host "Getting Past Events"
   $SVTevents_orig = Get-VIEvent -Start (Get-Date).AddDays($setDays) -Finish (Get-Date) |  Where { $_.Gettype().Name -eq "TaskEvent"} | Where {$_.Info} | Where {($_ | Select -ExpandProperty Info | Select DescriptionId) -match "com.simplivity"}
   $countSVTclones += ($SVTevents_orig | Where {$_.Info} | Where {($_ | Select -ExpandProperty Info | Select DescriptionId) -match "rapidclone.controller"}).count
   $countSVTbu += ($SVTevents_orig | Where {$_.Info} | Where {($_ | Select -ExpandProperty Info | Select DescriptionId) -match "com.simplivity.task.vmware.vm.snap.manual"}).count
   write-host "Number of clones: $countSVTclones"
   write-host "Number of backups: $countSVTbu"
   # Write initial counts to files
   $countSVTclones | Out-file -FilePath $clonefile -Force
   $countSVTbu | Out-file -FilePath $backupfile -Force

}

while ($true) {

   Write-Host "Sleeping for $setSeconds"
   Start-Sleep -s $setSeconds
   $SVTevents = Get-VIEvent -Start (Get-Date).AddMinutes($setMinutes) -Finish (Get-Date) |  Where { $_.Gettype().Name -eq "TaskEvent"} | Where {$_.Info} | Where {($_ | Select -ExpandProperty Info | Select DescriptionId) -match "com.simplivity"}
   
   #Get the current count from $clonefile
   [int]$countSVTclones = Get-Content $clonefile
   
   #Count SimpliVity Clones created in last $setMinutes and add to $countSVTclones
   $countSVTclones += ($SVTevents | Where {$_.Info} | Where {($_ | Select -ExpandProperty Info | Select DescriptionId) -match "rapidclone.controller"}).count
   #Display number of SimpliVity Clones
   write-host "Number of clones: $countSVTclones"
   # Write new count to $clonefile
   $countSVTclones | Out-file $clonefile

   #Get the current count from $backupfile
   [int]$countSVTbu = Get-Content $backupfile
   #Count SimpliVity Manual Backups created in last $setMinutes and add to $countSVTbu
   $countSVTbu += ($SVTevents | Where {$_.Info} | Where {($_ | Select -ExpandProperty Info | Select DescriptionId) -match "com.simplivity.task.vmware.vm.snap.manual"}).count
   #Display number of SimpliVity Manual Backups
   write-host "Number of backups: $countSVTbu"
   # Write new count to $backupfile
   $countSVTbu | Out-file $backupfile

   $SVTevents = ""

} #Keep Looping
