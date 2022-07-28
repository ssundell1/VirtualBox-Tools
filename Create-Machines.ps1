<#
    .SYNOPSIS
    Creates VirtualBox virtual machines from command line.

    .DESCRIPTION
    Creates virtual machines based on a JSON configuration file.

    .PARAMETER VBoxManage
    Path to the VBoxManage.exe binary from VirtualBox.
    Default = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

    .PARAMETER ConfigFile
    Path to the configuration file with virtual machine specificatins.
    Default = ".\example.json"

    .PARAMETER Workspace
    Path to the directory where the virtual machines will be created.
    Default = "C:\VirtualMachines"

    .PARAMETER Force
    Force script to purge any existing virtual machines with the same name as a new machine.
    Default = False

    .PARAMETER TurnOn
    Tell VirtualBox to power on the machine after they have been created.
    Default = False

    .INPUTS
    None. You cannot pipe objects to Create-Machines.ps1.

    .OUTPUTS
    None.
#>

param(
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$ConfigFile = ".\example.json",
    [Parameter()][string]$Workspace = "C:\VirtualMachines",
    [Parameter()][switch]$Force = $False,
    [Parameter()][switch]$TurnOn
 )

if(!(Test-Path $ConfigFile)) {
    Throw "Could not find config file!"
}
$Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

& "$PSScriptRoot\Check-Config" -ConfigFile $ConfigFile
& "$PSScriptRoot\Purge-Machines.ps1" -ConfigFile $ConfigFile -Force $Force
& "$PSScriptRoot\Clean-Registered-Disks.ps1" -ConfigFile $ConfigFile

Write-Host '================================================================'
Write-Host 'Creating machines...'
Write-Host '================================================================'

ForEach ($Machine in $Config.Machines) {
    # Create VM
    Write-Host $Machine.Name'...'
    & $VBoxManage createvm --name $Machine.Name --basefolder $Workspace --register > $null
    # Set firmware
    Write-Host "Set firmare"
    & $VBoxManage modifyvm $Machine.Name --firmware $Machine.Firmware > $null
    # Set Memory
    Write-Host "Set Memory"
    & $VBoxManage modifyvm $Machine.Name --memory $Machine.Memory > $null
    # Set VideoMemory
    Write-Host "Set VideoMemory"
    & $VBoxManage modifyvm $Machine.Name --vram $Machine.VideoMemory > $null
    # Enable USB 3.0
    Write-Host "Enable USB 3.0"
    & $VBoxManage modifyvm $Machine.Name --usbxhci on > $null

    $NetAdapterIndex = 1
    ForEach($NetworkAdapter in $Machine.NetworkAdapters) {
        # Add Network Adapters
        Write-Host "Add Network Adapters"
        if($NetworkAdapter.Type -eq "hostonly") {
            & $VBoxManage modifyvm $Machine.Name `
            --nic$NetAdapterIndex $NetworkAdapter.Type `
            --hostonlyadapter$NetAdapterIndex $NetworkAdapter.HostOnlyAdapter > $null
        }
        if($NetworkAdapter.Type -eq "bridged") {
            & $VBoxManage modifyvm $Machine.Name `
            --nic$NetAdapterIndex $NetworkAdapter.Type `
            --bridgeadapter$NetAdapterIndex $NetworkAdapter.BridgeAdapter > $null
        }
        $NetAdapterIndex++
    }

    # Storage Controllers
    ForEach ($Controller in $Machine.Storage.Controllers) {
        # Create storage controllers
        Write-Host "Create storage controllers"
        & $VBoxManage storagectl $Machine.Name `
            --name $Controller.Name `
            --add $Controller.Type `
            --controller $Controller.Logic `
            --bootable $Controller.Bootable > $null

        # Enable Host I/O Caching
        & $VBoxManage storagectl $Machine.Name `
        --name $Controller.Name `
        --hostiocache on > $null
        
        $AttachmentIndex = 0
        ForEach($Attachment in $Controller.Attachments) {
            Write-Host "Handle attachments"
            # Check if file exists
            if(Test-Path($Attachment.FileName)) {
                Write-Host $Attachment.FileName"found. Attaching..."
                $FilePath = $Attachment.FileName
            } else {
                # If it doesn't exist, create a new virtual hdd
                if($Attachment.Size -ne "") {
                    # Create medium
                    if($Attachment.FileName -eq "") {
                        Write-Warning "No file name found for storage attachment. Generated $($Machine.Name).vmdk"
                        $Attachment.FileName = "$($Machine.Name).vmdk"
                    }
                    $FilePath = Join-Path $Workspace $Machine.Name $Attachment.FileName
                    & $VBoxManage createmedium disk `
                        --filename $FilePath `
                        --size $Attachment.Size `
                        --format VMDK > $null
                }
            }
            # Create storage attachments
            & $VBoxManage storageattach $Machine.Name `
                --storagectl $Controller.Name `
                --type $Attachment.Type `
                --medium $FilePath `
                --port $AttachmentIndex > $null

            $AttachmentIndex++
        }
    }
    # Check to make sure VM exists
    $RegisteredMachines = & $VBoxManage list vms
    if($RegisteredMachines -match $Machine.Name) {
        Write-Host -ForegroundColor Green -Object 'Success!'
    } else {
        Write-Host -ForegroundColor Red -Object 'Failed!'
    }

    # Start VM if TurnOn switch is supplied
    If($TurnOn) {
        Write-Host 'Starting Machine...'
        & $VBoxManage startvm $Machine.Name
    }
}