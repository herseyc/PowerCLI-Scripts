####################################################################
# Uses vCenter Real Time Performance Stats to
# collect real time counters for Read/Write IOPS for All VMs/Disks 
# and writes data to file
#
# http://www.vhersey.com/
#
####################################################################
# vCenter Server
$vcenter = "192.168.1.21"

# Number of 20 second samples to collect
$samples = 4320
# 1 Minute = 3
# 1 Hour = 180
# 1 Day = 4320

# File to store stats
$file = "C:\Utilities\Collect-IOPS.csv"

################ HERE WE GO ####################
# Create New File
New-Item $file -type file -force
#Add Column Headers to File
Add-Content $file "TimeStamp, VM, Disk, Read, Write"

# Connect to vCenter
Connect-Viserver $vcenter

Write-Host "Collecting $samples Samples"

function Collect-IOPS {

   #Get VMs
   $vms = Get-VM

   #IOPS - Thanks to LucD http://www.lucd.info/2011/04/22/get-the-maximum-iops/
   $metrics = "virtualdisk.numberwriteaveraged.average","virtualdisk.numberreadaveraged.average"
   $stats = Get-Stat -Realtime -Stat $metrics -Entity ($vms | Where {$_.PowerState -eq "PoweredOn"}) -MaxSamples 1
   $interval = $stats[0].IntervalSecs
 
   $hdTab = @{}
      foreach($hd in (Get-Harddisk -VM ($vms | Where {$_.PowerState -eq "PoweredOn"}))){
          $controllerKey = $hd.Extensiondata.ControllerKey
          $controller = $hd.Parent.Extensiondata.Config.Hardware.Device | where{$_.Key -eq $controllerKey}
          $hdTab[$hd.Parent.Name + "/scsi" + $controller.BusNumber + ":" + $hd.Extensiondata.UnitNumber] = $hd.FileName.Split(']')[0].TrimStart('[')
   }

   $iops = $stats | Group-Object -Property {$_.Entity.Name},Instance

   foreach ($collected in $iops) {
       $readios = ($collected.Group | Group-Object -Property Timestamp | %{$_.Group[1].Value} | Measure-Object -Maximum).Maximum
       $writeios = ($collected.Group | Group-Object -Property Timestamp | %{$_.Group[0].Value} | Measure-Object -Maximum).Maximum
       $timestamp = $collected.Group | Group-Object -Property Timestamp
       $ts = $timestamp.Name
       $vmname = $collected.Values[0]
       $vmdisk = $collected.Values[1]
       #TimeStamp, VM, Disk, Read IOPS, Write IOPS
       $line = "$ts,$vmname,$vmdisk,$readios,$writeios"
       # Write-Host $line
       Add-Content $file "$line"
   } 

}

For ($i = 1; $i -le $samples; $i+=1) {
    Write-Host "Collecting Sample $i"
    Collect-IOPS
    Write-Host "Sleeping for $interval"
    start-sleep -s $interval
}

Disconnect-Viserver $vcenter -Confirm:$false -WarningAction SilentlyContinue
