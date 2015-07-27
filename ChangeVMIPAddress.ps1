#######################################
# PowerCLI to replace guest network information for restored VMs with new IP Address, Gateway and DNS Servers
# example: Original IP Address is 192.168.1.252, change to 172.28.238.252
#
# Must be connected to vCenter or ESXi using Connect-VIServer
#
# Script: ChangeVMIPAddress.ps1
#
# History:
# 7/26/2015 - Hersey http://www.vhersey.com/ - Created
#
###############VARIABLES###############
#Original IP to replace"
$origIp = "192.168.2."

#New IP Information
$newIp = "192.168.1."
$newMask = "255.255.255.0"
$newGateway = "192.168.1.1"
$newDNS = "192.168.1.150"

#Guest Credentials - Must have required permissions to change IP address
$GuestUserName = "Administrator"
$GuestPassword = "Password"

#VM Inventory names to match
$matchVMs = "restore"

##############NO CHANGES BEYOND THIS POINT##############
#List of VMs (vCenter Inventory Names) to change
$VMs = (get-vm | where {$_.Name -match $matchVMs -and $_.PowerState -eq "PoweredOn"}).Name

foreach ($vm in $VMs) {
   #PowerShell used by Invoke-VMScript to retrieve current IP Address
   $ipscript = '(Get-NetIPAddress | where-object {$_.IPAddress -match "' + $origIp + '" -and $_.AddressFamily -eq "IPv4"}).IPAddress'
   $currentIp = invoke-vmscript -ScriptText $ipscript -ScriptType PowerShell -VM $vm -GuestUser $GuestUserName -GuestPassword $GuestPassword
   $currentIp = $currentIp -replace "`t|`n|`r",""
   write-host "$currentIp is the current IP Address"

   #Adjust Original IP to Replacement IP
   $changeIp = $currentIp.replace("$origIp", "$newIp")
   $changeIp = $changeIp -replace "`t|`n|`r",""
   Write-Host "Changing IP to $changeIp"

   #Get the Interface Name (Alias)
   $aliasscript = '(Get-NetIPAddress | where-object {$_.IPAddress -match "' + $origIp + '" -and $_.AddressFamily -eq "IPv4"}).InterfaceAlias'
   $getIntAlias = invoke-vmscript -ScriptText $aliasscript -ScriptType PowerShell -VM $vm -GuestUser $GuestUserName -GuestPassword $GuestPassword
   $getIntAlias = $getIntAlias -replace "`t|`n|`r",""
   write-host "The interface name is $getIntAlias"

   #Change the IP Address
   $changingIp = 'C:\windows\system32\netsh.exe interface ipv4 set address name="' + $getIntAlias + '" source=static address=' + $changeIp + ' mask=' + $newMask + ' gateway=' + $newGateway + ' gwmetric=1 store=persistent'
   Write-host "Changing IP Address of $vm interface $getIntAlias from $currentIp to $changeIp"
   $setIp = invoke-vmscript -ScriptText $changingIp -ScriptType bat -VM $vm -GuestUser $GuestUserName -GuestPassword $GuestPassword

   #Change DNS Servers
   Write-Host "Setting DNS Server to $newDNS"
   $changeDNS = 'C:\windows\system32\netsh.exe interface ipv4 set dnsservers name="' + $getIntAlias + '" source=static address=' + $newDNS + ' register=primary'
   $setDNS = invoke-vmscript -ScriptText $changeDNS -ScriptType bat -VM $vm -GuestUser $GuestUserName -GuestPassword $GuestPassword
}

   
