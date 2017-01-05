###############################################################
#
# Quick and dirty way to use PowerShell to add an entry 
# to an ESXi host's /etc/hosts file
#
# http://www.vhersey.com/
#
###############################################################

#Connectivity Information
$Username = "root" # ESXi Username
$Password = "VMware1!" # ESXi Password
$esxihost = "192.168.1.25" # ESXi Host IP

#New Host Entry
$addIP = "192.168.1.151"
$addHostname = "newhostsname"

### Ignore TLS/SSL errors
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
 
### Create authorization string and store in $head
$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Username + ":" + $Password))
$head = @{"Authorization"="Basic $auth"}

# Request current hosts file
Write-Host "Retrieving current /etc/hosts file from $esxihost" -ForeGroundColor Green
$requesthostsfile = Invoke-WebRequest -Uri https://$esxihost/host/hosts -Method GET -ContentType "text/plain" -Headers $head

if ( $requesthostsfile.StatusCode -ne "200" ) {
   Write-Host "Unable to retrieve current /etc/hosts file from $esxihost" -ForeGroundColor Red
   Exit
}

# Add new line to hosts file with $addIP and $addHostname
$newhostsfile = $requesthostsfile.Content
$newhostsfile += "`n$addIP`t$addHostname`n"

Write-Host "Contents of new /etc/hosts" -ForeGroundColor Green
Write-Host "-------------------------------------------------------"
Write-Host $newhostsfile
Write-Host "-------------------------------------------------------"

# Put the new hosts file on the host
Write-Host "Putting new /etc/hosts file on $esxihost"
$puthostsfile = Invoke-WebRequest -Uri https://192.168.1.25/host/hosts -Method PUT -ContentType "text/plain" -Headers $head -Body $newhostsfile

if ( $puthostsfile.StatusCode -ne "200" ) {
   Write-Host "Unable to put new /etc/hosts file on $esxihost" -ForeGroundColor Red
   Exit
}
Write-Host "Done!" -ForeGroundColor Green


