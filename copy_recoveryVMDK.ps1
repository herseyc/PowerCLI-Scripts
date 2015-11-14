########################################################################################################
# PowerCLI script to copy a vmdk from one VM (a recovery VM) to another VM (the target VM)
# Usage copy_recoveryVMDK.ps1 
#
# Requires active connection to vCenter Server (using connect-viserver)
#
# History:
# 11/14/2015 - Hersey http://www.vhersey.com/ - Created
#
########################################################################################################
#Variables
# Recovery VM Inventory Name which contains the vmdk to copy
$Source = "CLONELABFILE01"

# Target VM Inventory Name where vmdk will be copied to
$Target = "LABFILE01"

# Define which Virtual Hard Disk is the vmdk to copy from Recovery VM to Target VM
$recoveryHD = "Hard disk 3"

Clear-Host 

Write-Host "Here. We. Go!" -ForeGroundColor Cyan

#Get Working Directory of Target VM
Write-Host "Determining Working Directory of Target VM ..." -ForeGroundColor Cyan
$targetVM = Get-VM $Target 
$targetWORK = $targetVM | Get-HardDisk | Where {$_.Name -eq "Hard disk 1"} 
$targetDIR = $targetWORK.Filename.Split("/")[0]

#Set location and name of new VMDK
$dateTime = Get-Date -Format MMddyyhhmmss #Just an attempt to add some uniqueness to the vmdk file name.
$NewVMDK = "$targetDIR/recovery-VM-$dateTime.vmdk"

#Copy VMDK from Recovery VM to Target VM Working Directory
Write-Host "Copying $recoveryHD from $Source to $Target $NewVMDK ..." -ForeGroundColor Cyan
$recoveryVM = Get-VM $Source
$recoveryWORK = $recoveryVM | Get-HardDisk | Where {$_.Name -eq "$recoveryHD"} | Copy-HardDisk -DestinationPath $NewVMDK

#Attach copied VMDK to Target VM
Write-Host "Attaching $NewVMDK to $Target ..." -ForeGroundColor Cyan
$targetVM | New-HardDisk -DiskPath $NewVMDK | Out-Null

Write-Host "Done!" -ForeGroundColor Cyan
