# Import our PowerCLI modules
import-module vmware.vimautomation.core,vmware.vimautomation.vds
# Boring Variables
$host_un = "root"
$host_pw = "VMware1!"

# Import our JSON
$config = get-content .\env_config.json | convertfrom-json
# Configure our host(s) first
$esxhosts = $config.esxi_hosts
# Loop through our hosts
foreach ($esxhost in $esxhosts) {
  Connect-VIServer -Server $($esxhost.network.vmkernel.mgmt.ip) -User $host_un -Password $host_pw;
  # Configure hostname
  $esxcli = Get-EsxCli
  $esxcli.system.hostname.set($null,$esxhost.name,$null);
  # Configure DNS Server - here we check if it is deployed correctly
  if ($(Get-VMHostNetwork | select -expand dnsaddress) -ne $config.globals.dns_server) {
    Write-Output "Changing DNS server to $config.globals.dns_server"
    Get-VMHostNetwork | Set-VMHostNetwork -DnsFromDhcp:$false -DnsAddress $config.globals.dns_server
  } else {
    Write-Output "DNS server was fine, not changing"
  }
  # Configure our vSwitch
  $vswitch = get-virtualswitch -name vswitch0
  if (($vswitch | select nic | measure).count) -ne $esxhost.network.uplinks.count) {
    Write-Output $("Invalid number of uplinks found on vSwitch, expected  "+$esxhost.network.uplinks.count)
    $nics = $esxhost.network.uplinks
    Set-VirtualSwitch $vswitch -Nic $($nics -join ",")
  } else {
    Write-Output "vSwitch uplinks are all good"
  }
  # Create VMkernel ports
  $pgs = $vswitch | get-virtualportgroup
  
  Disconnect-VIServer * -Confirm:$false;
}
