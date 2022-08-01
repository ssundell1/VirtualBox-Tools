param(
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$ConfigFile,
    [Parameter()][bool]$Force = $False,
    [Parameter()][string]$Workspace = "C:\VirtualMachines"
 )

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

$RegisteredMachines = & $VBoxManage list vms

Write-Host '================================================================'
Write-Host 'Purging any existing machines...'
Write-Host '================================================================'

ForEach($Machine in $Config.Machines) {
    if($RegisteredMachines -match $Machine.Name) {
        Write-Host "Machine $($Machine.Name) is registered in VirtualBox."
        If($Force) {
            Write-Host "`tForce flag set. Unregistering VM..."
            & $VBoxManage unregistervm $Machine.Name > $null
        } Else {
            Write-Warning "Force flag is not set. Will leave registered VM alone."
        }
    } else {
        Write-Host "Machine $($Machine.Name) is not registered in VirtualBox."
    }
    if(Test-Path (Join-Path -Path $Workspace -Child $Machine.Name)) {
        Write-Host "`tMachine $($Machine.Name) still has files."
        If($Force) {
            Write-Host "Force flag set. Deleting VM files..."
            Remove-Item (Join-Path -Path $Workspace -Child $Machine.Name) -Recurse -Force > $null
        } Else {
            Write-Warning "Force flag is not set. Will leave existing VM files."
            Throw "Use Force flag to remove existing VMs"
        }
    } else {
        Write-Host "Machine $($Machine.Name) does not have any residual files."
    }

    $RegisteredMachines = & $VBoxManage list vms
    if($RegisteredMachines -match $Machine.Name) {
        Write-Host -ForegroundColor Red -Object "Failed to delete!"
    } else {
        Write-Host -ForegroundColor Green -Object "Success!"
    }
}