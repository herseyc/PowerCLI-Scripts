# collect-vcdc-info.ps1
#
# Collect information about Hosts in Datacenters
# Information like Number of CPUs, Number of Cores, Memory, Diskspace, and more...
#
# Connect to vCenter Server using Connect-VIServer
#
#
#Set Disk Size (GB) threshold for determining large capacity VMs
$bigvmthreshold = "500"

#Number of Days to get Average CPU, Memory, and IOPS
$start = (Get-Date).AddDays(-5)

#Get Datacenters
$dcenters = Get-Datacenter

foreach ( $dc in $dcenters ) {

   #Print out Datacenter Name
   $dc.Name

   #Individual Host Resource Information
   $hostinfo = get-View -ViewType HostSystem -SearchRoot $dc.id | Select @{n="Host"; e={(Get-VMHost -Id $_.Moref).Name}},
      @{n="NumCpuSockets"; e={$_.Hardware.CpuInfo.NumCpuPackages}},
      @{n="NumCpuCores";e={$_.Hardware.CpuInfo.NumCpuCores}},
      @{n="NumCpuThreads";e={$_.Hardware.CpuInfo.NumCpuThreads}},
      @{n="CPUperCoreGHz";e={[math]::round((($_.Hardware.CpuInfo.Hz)/1024/1024/1024), 2)}},
      @{n="CPUinGHz";e={[math]::round((($_.Hardware.CpuInfo.Hz)/1024/1024/1024)*($_.Hardware.CpuInfo.NumCpuCores), 2)}},
      @{n="MemorySizeGB";e={[math]::round(($_.Hardware.MemorySize)/1024/1024/1024)}}

   $hosttotals = $hostinfo | Measure-Object -Sum NumCpuSockets, NumCpuCores, NumCpuThreads, CPUinGHz, MemorySizeGB

   #Total Host Resources in Datacenter
   $hostoutput = New-Object -Type PSObject -Property @{
      NumberHosts = $hosttotals[0].Count
      TotalCpuSockets = ($hosttotals | ?{$_.Property -eq "NumCpuSockets"}).Sum
      TotalCpuCores = ($hosttotals | ?{$_.Property -eq "NumCpuCores"}).Sum
      TotalCpuThreads = ($hosttotals | ?{$_.Property -eq "NumCpuThreads"}).Sum
      TotalCPUinGHz = ($hosttotals | ?{$_.Property -eq "CPUinGHz"}).Sum
      TotalMemoryGB = ($hosttotals | ?{$_.Property -eq "MemorySizeGB"}).Sum
   }

   #Get hosts in Datacenter
   $dchosts = $dc | get-vmhost

   #Get Point in Time Host Utilization
   $hostusage = $dchosts | Measure-Object -Sum CpuUsageMhz, MemoryUsageGB
   $hostutilization = New-Object -Type PSObject -Property @{
      NumberHosts = $hostusage[0].Count
      CpuUsageGhz = [math]::round((($hostusage | ?{($_.Property -eq "CpuUsageMhz")}).Sum)/1024, 2)
      MemoryUsageGB = [math]::round(($hostusage | ?{($_.Property -eq "MemoryUsageGB")}).Sum, 2)
   }

   #Host Average Utilization
   $memoryusage = Get-Stat -Entity $dchosts -Stat "mem.consumed.average" -Start $start -Finish (Get-Date) | Group-Object -Property MetricId
   $avgmemory = ($memoryusage.Group | Measure-Object -Property Value -Average).Average
   $cpuusage = Get-Stat -Entity $dchosts -Stat "cpu.usagemhz.average" -Start (Get-Date).AddDays(-14) -Finish (Get-Date) | Group-Object -Property MetricId
   $avgcpu = ($cpuusage.Group | Measure-Object -Property Value -Average).Average

   #Average Utilization of CPU, Memory and Disk
   $avgutilization = New-Object -Type PSObject -Property @{
      FourteenDayAvgCPUGHz = [math]::round(($avgcpu)/1024, 2)
      FourteenDayAvgMemGB = [math]::round(($avgmemory)/1024/1024, 2)
   }

   #Get-VMs
   $vms = $dc | Get-VM 

   #Determine if there are any large VMs over the $bigvmthreshold
   $largevms = $vms | Where {$_.ProvisionedSpaceGB -gt $bigvmthreshold} | Select @{n="Name"; e={$_.Name}},
      @{n="ProvisionedSpaceGB";e={[math]::round(($_.ProvisionedSpaceGB), 2)}},
      @{n="UsedSpaceGB";e={[math]::round(($_.UsedSpaceGB), 2)}}

   #Determine number of VMs powered on and powered off
   $onvms =  ($vms | Where {$_.PowerState -eq "PoweredOn"}).count
   $offvms =  ($vms | Where {$_.PowerState -eq "PoweredOff"}).count

   #IOPS - Thanks to LucD http://www.lucd.info/2011/04/22/get-the-maximum-iops/
   $metrics = "virtualdisk.numberwriteaveraged.average","virtualdisk.numberreadaveraged.average"
   $stats = Get-Stat -Realtime -Stat $metrics -Entity ($vms | Where {$_.PowerState -eq "PoweredOn"}) -Start $start 
   $interval = $stats[0].IntervalSecs
 
   $hdTab = @{}
   foreach($hd in (Get-Harddisk -VM ($vms | Where {$_.PowerState -eq "PoweredOn"}))){
       $controllerKey = $hd.Extensiondata.ControllerKey
       $controller = $hd.Parent.Extensiondata.Config.Hardware.Device | where{$_.Key -eq $controllerKey}
       $hdTab[$hd.Parent.Name + "/scsi" + $controller.BusNumber + ":" + $hd.Extensiondata.UnitNumber] = $hd.FileName.Split(']')[0].TrimStart('[')
   }
 
   $iops = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
       New-Object PSObject -Property @{
           VM = $_.Values[0]
           Disk = $_.Values[1]
           IOPSMaxWrite = ($_.Group | `
           Group-Object -Property Timestamp | `
           %{$_.Group[0].Value} | `
           Measure-Object -Maximum).Maximum 
           IOPSMaxRead = ($_.Group | `
           Group-Object -Property Timestamp | `
           %{$_.Group[1].Value} | `
           Measure-Object -Maximum).Maximum 
           IOPSMax = ($_.Group | `
           Group-Object -Property Timestamp | `
           %{$_.Group[0].Value + $_.Group[1].Value} | `
           Measure-Object -Maximum).Maximum 
           Datastore = $hdTab[$_.Values[0] + "/"+ $_.Values[1]]
       }
   }

   #Total IOPS 
   $iopstotals = $iops | Measure-Object -Sum IOPSMaxWrite, IOPSMaxRead, IOPSMax
   $totaliops = New-Object -Type PSObject -Property @{
      TotalIOPSMax = ($iopstotals | ?{$_.Property -eq "IOPSMax"}).Sum
      PercentWrite = [math]::round((($iopstotals | ?{$_.Property -eq "IOPSMaxWrite"}).Sum / ($iopstotals | ?{$_.Property -eq "IOPSMax"}).Sum)*100)
      PercentRead = [math]::round((($iopstotals | ?{$_.Property -eq "IOPSMaxRead"}).Sum / ($iopstotals | ?{$_.Property -eq "IOPSMax"}).Sum)*100)
      TotalIOPSReadMax = ($iopstotals | ?{$_.Property -eq "IOPSMaxRead"}).Sum
      TotalIOPSWriteMax = ($iopstotals | ?{$_.Property -eq "IOPSMaxWrite"}).Sum
   }

   #VM Resource Totals
   $totalvms = $vms | Measure-Object -Sum NumCpu, ProvisionedSpaceGB, UsedSpaceGB, MemoryGB
   $vmsoutput = New-Object -Type PSObject -Property @{
      TotalVMs = $totalvms[0].Count
      PoweredOnVMs = $onvms
      PoweredOffVMs = $offvms
      TotalvCPUs = ($totalvms | ?{$_.Property -eq "NumCpu"}).Sum
      ProvisionedDiskSpaceGB = [math]::round((($totalvms | ?{$_.Property -eq "ProvisionedSpaceGB"}).Sum), 2)
      UsedDiskSpaceGB = [math]::round((($totalvms | ?{$_.Property -eq "UsedSpaceGB"}).Sum), 2)
      AllocatedMemoryGB = [math]::round((($totalvms | ?{$_.Property -eq "MemoryGB"}).Sum), 2)
      vCPUtoCoreRatio = (($totalvms | ?{$_.Property -eq "NumCpu"}).Sum / $hostoutput.TotalCPUCores)
   }
  
   

   $report = $hostinfo | Select Host, NumCpuSockets, NumCpuCores, NumCpuThreads, CPUperCoreGHz, CPUinGHz, MemorySizeGB | ft

   $report += $hostoutput | Select NumberHosts, TotalCpuSockets, TotalCpuCores, TotalCpuThreads, TotalCPUinGHz, TotalMemoryGB | ft

   $report += $hostutilization | Select CpuUsageGhz, MemoryUsageGB | ft

   $report += $avgutilization | Select FourteenDayAvgCPUGHz, FourteenDayAvgMemGB | ft

   $report += $vmsoutput | Select TotalVMs, PoweredOnVMs, PoweredOffVMs, TotalvCPUs, ProvisionedDiskSpaceGB, UsedDiskSpaceGB, AllocatedMemoryGB, vCPUtoCoreRatio | ft

   $report += $largevms | Select Name, ProvisionedSpaceGB, UsedSpaceGB | ft

   $report += $iops | Select VM, Datastore, Disk, IOPSMaxWrite, IOPSMaxRead | ft

   $report += $totaliops | Select TotalIOPSWriteMax, PercentWrite, TotalIOPSReadMax, PercentRead, TotalIOPSMax | ft

   $report

}


