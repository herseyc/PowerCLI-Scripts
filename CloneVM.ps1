########################################################
# Create Clones of a Source VM
# CloneVM.ps1 -VM SourceVM -NumVMs NumberofClones
# 
# Hersey - http://www.vhersey.com/
#
########################################################
#Get Parameters
param(
 [Parameter(Mandatory=$true, HelpMessage=”Inventory Name of VM to Clone”)][string]$VM,
 [Parameter(Mandatory=$true, HelpMessage=”Number of Clones to Create”)][string]$NumVMs
)

#Get SourceVM Info
$vminfo = Get-VM $VM 
$vmhost = $vminfo.VMHost.name
$x = $vm.ExtensionData.Config.Files.VmPathName -match "\[(.*?)\]"
$ds = $matches[1]

$vmcount = $NumVMs

1..$vmcount | foreach {
   #Set New VM Name
   $append=”{0:D3}” -f $_
   $vmname= $VM + $append

   #Clone the VM
   write-host " Creating $VM_name "
   New-VM -Name $vmname -VM $VM -VMHost $vmhost -Datastore $ds -RunAsync
}
