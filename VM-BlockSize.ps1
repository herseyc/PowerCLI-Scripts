###################################################################
#
# Generates HTML Report of Volume Formatted Filesystem, Blocksize, Capacity, and Free Space
# for all Running Windows VMs
# Usage: VM-BlockSize.ps1
#
# 01/16/2016 - Hersey - http://www.vhersey.com/
#
###################################################################
# Variables
$ReportFile = "C:\Utilities\VMVol.html"
$vCenterFQDN = "192.168.1.27"

############# Here we go ############# 
# Get vCenter Credentials
$vCenterCredential = Get-Credential -Message "vCenter User Credentials"

# Connect to vCenter Server
connect-VIServer $vCenterFQDN -Credential $vCenterCredential

# Get Domain User Credentials
$DomainCredential = Get-Credential -Message "Domain User Credentials"

# Get IP Address of Powered On Windows VMs
$VMs = (get-vm | where {$_.guest.OSFullName -match "Windows" -and $_.PowerState -eq "PoweredOn"} | Get-VMGuest).IPAddress

$report = "<h1>Volume Blocksize Report</h1>"

# Connect to each VM and generate volume report.
foreach ( $vm in $VMs ) {

  $report  = $report + "<h2>Volume Blocksize Report for VM $vm</h2>"

  # Query to get Volume Information
  $wql = "SELECT Label, Blocksize, Name, Capacity, FreeSpace, FileSystem FROM Win32_Volume"

  $voltable = Get-WmiObject -Query $wql -ComputerName $vm -Credential $DomainCredential | ConvertTo-HTML Name, Label, FileSystem, Blocksize, Capacity, FreeSpace -Fragment

  $report = $report + $voltable

}

# Create HTML Report
ConvertTo-Html -Body "$report" -Title "VM Volume Blocksize Report" | Out-File $ReportFile

# Open HTML Report
Start $ReportFile

# Disconnect from vCenter Server
Disconnect-VIServer $vCenterFQDN -confirm:$false
