# collect-vcdc-info.ps1
#
# Collect information about Hosts in Datacenters
# Information like Number of CPUs, Number of Cores, Memory, Diskspace, and more...
#
# Connect to vCenter Server using Connect-VIServer
#
#
$dcenters = Get-Datacenter

foreach ( $dc in $dcenters ) {

   $dc.Name

   $hostinfo = get-View -ViewType HostSystem -SearchRoot $dc.id | Select @{n="Host"; e={(Get-VMHost -Id $_.Moref).Name}},
      @{n="NumCpuSockets"; e={$_.Hardware.CpuInfo.NumCpuPackages}},
      @{n="NumCpuCores";e={$_.Hardware.CpuInfo.NumCpuCores}},
      @{n="NumCpuThreads";e={$_.Hardware.CpuInfo.NumCpuThreads}},
      @{n="CPUperCoreGHz";e={[math]::round((($_.Hardware.CpuInfo.Hz)/1024/1024/1024), 2)}},
      @{n="CPUinGHz";e={[math]::round((($_.Hardware.CpuInfo.Hz)/1024/1024/1024)*($_.Hardware.CpuInfo.NumCpuCores), 2)}},
      @{n="MemorySizeGB";e={[math]::round(($_.Hardware.MemorySize)/1024/1024/1024)}}

   $hosttotals = $hostinfo | Measure-Object -Sum NumCpuSockets, NumCpuCores, NumCpuThreads, CPUinGHz, MemorySizeGB

   $hostoutput = New-Object -Type PSObject -Property @{
	   NumberHosts = $hosttotals[0].Count
	   TotalCpuSockets = ($hosttotals | ?{$_.Property -eq "NumCpuSockets"}).Sum
	   TotalCpuCores = ($hosttotals | ?{$_.Property -eq "NumCpuCores"}).Sum
	   TotalCpuThreads = ($hosttotals | ?{$_.Property -eq "NumCpuThreads"}).Sum
     TotalCPUinGHz = ($hosttotals | ?{$_.Property -eq "CPUinGHz"}).Sum
     TotalMemoryGB = ($hosttotals | ?{$_.Property -eq "MemorySizeGB"}).Sum
   }

   $vms = $dc | Get-VM 

   $onvms =  ($vms | Where {$_.PowerState -eq "PoweredOn"}).count
   $offvms =  ($vms | Where {$_.PowerState -eq "PoweredOff"}).count

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


   $hostinfo | Select Host, NumCpuSockets, NumCpuCores, NumCpuThreads, CPUperCoreGHz, CPUinGHz, MemorySizeGB | ft

   $hostoutput | Select NumberHosts, TotalCpuSockets, TotalCpuCores, TotalCpuThreads, TotalCPUinGHz, TotalMemoryGB | ft

   $vmsoutput | Select TotalVMs, PoweredOnVMs, PoweredOffVMs, TotalvCPUs, ProvisionedDiskSpaceGB, UsedDiskSpaceGB, AllocatedMemoryGB, vCPUtoCoreRatio | ft


}
