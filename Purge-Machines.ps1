param(
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$ConfigFile = ".\example.json",
    [Parameter()][bool]$Force = $False
 )

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

$RegisteredMachines = & $VBoxManage list vms

Write-Host '================================================================'
Write-Host 'Purging any existing machines...'
Write-Host '================================================================'

ForEach($Machine in $Config.Machines) {
    if($RegisteredMachines -match $Machine.Name) {
        Write-Host 'Machine'$Machine.Name'exists.'
        If($Force) {
            Write-Host 'Force flag set. Deleting VM...'
            & $VBoxManage unregistervm --delete $Machine.Name > $null
        } Else {
            Throw 'Force flag is not set. Will leave existing VMs. Exiting.'
        }
    } else {
        Write-Host 'Machine'$Machine.Name'does not exist.'
    }

    $RegisteredMachines = & $VBoxManage list vms
    if($RegisteredMachines -match $Machine.Name) {
        Write-Host -ForegroundColor Red -Object "Failed to delete!"
    } else {
        Write-Host -ForegroundColor Green -Object "Success!"
    }
}