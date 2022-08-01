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

    .PARAMETER Start
    Tell VirtualBox to power on the machine after they have been created.
    Default = False

    .INPUTS
    None. You cannot pipe objects to Create-Machines.ps1.

    .OUTPUTS
    None.
#>

param(
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$ConfigFile,
    [Parameter()][string]$Workspace = "C:\VirtualMachines",
    [Parameter()][switch]$Force = $False,
    [Parameter()][switch]$Start
 )

if($ConfigFile -eq "") {
    Throw "No configuration (-ConfigFile) file supplied. See example.json"
}

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
    Write-Host "`t-Set Firmare"
    Write-Host "`t`t[$($Machine.Firmware)]"
    & $VBoxManage modifyvm $Machine.Name --firmware $Machine.Firmware > $null
    # Set Memory
    Write-Host "`t-Set Memory"
    Write-Host "`t`t[$($Machine.Memory) MB]"
    & $VBoxManage modifyvm $Machine.Name --memory $Machine.Memory > $null
    # Set VideoMemory
    Write-Host "`t-Set VideoMemory"
    Write-Host "`t`t[$($Machine.VideoMemory) MB]"
    & $VBoxManage modifyvm $Machine.Name --vram $Machine.VideoMemory > $null
    # Enable USB 3.0
    Write-Host "`t-Enable USB 3.0"
    & $VBoxManage modifyvm $Machine.Name --usbxhci on > $null

    $NetAdapterIndex = 1
    Write-Host "`t-Add Network Adapters"
    ForEach($NetworkAdapter in $Machine.NetworkAdapters) {
        # Add Network Adapters
        if($NetworkAdapter.Type -eq "hostonly") {
            Write-Host "`t`t[NIC$($NetAdapterIndex) - $($NetworkAdapter.Type) - $($NetworkAdapter.HostOnlyAdapter)]"
            & $VBoxManage modifyvm $Machine.Name `
            --nic$NetAdapterIndex $NetworkAdapter.Type `
            --hostonlyadapter$NetAdapterIndex $NetworkAdapter.HostOnlyAdapter > $null
        }
        if($NetworkAdapter.Type -eq "bridged") {
            Write-Host "`t`t[NIC$($NetAdapterIndex) - $($NetworkAdapter.Type) - $($NetworkAdapter.BridgeAdapter)]"
            & $VBoxManage modifyvm $Machine.Name `
            --nic$NetAdapterIndex $NetworkAdapter.Type `
            --bridgeadapter$NetAdapterIndex $NetworkAdapter.BridgeAdapter > $null
        }
        $NetAdapterIndex++
    }

    # Storage Controllers
    Write-Host "`t-Create storage controllers"
    ForEach ($Controller in $Machine.Storage.Controllers) {
        # Create storage controllers
        Write-Host "`t`t[$($Controller.Logic) $($Controller.Type) controller $($Controller.Name)]"
        & $VBoxManage storagectl $Machine.Name `
            --name $Controller.Name `
            --add $Controller.Type `
            --controller $Controller.Logic `
            --bootable $Controller.Bootable > $null

        # Enable Host I/O Caching
        Write-Host "`t`t`tEnabling Host I/O Caching..."
        & $VBoxManage storagectl $Machine.Name `
        --name $Controller.Name `
        --hostiocache on > $null
        
        $AttachmentIndex = 0
        ForEach($Attachment in $Controller.Attachments) {
            Write-Host "`t-Handle attachments"
            # Check if file exists
            if(Test-Path($Attachment.FileName)) {
                Write-Host "`t`t[$($Attachment.FileName) found]"
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
                    Write-Host "`t`t[$($Attachment.FileName)]"
                    Write-Host "`t`t`tCreating new disk $($Attachment.FileName) - $($Attachment.Size)..."
                    Write-Host "`t`t`t" -NoNewLine
                    & $VBoxManage createmedium disk `
                        --filename $FilePath `
                        --size $Attachment.Size `
                        --format VMDK > $null
                }
            }
            # Create storage attachments
            Write-Host "`t`t`tAttaching $($Attachment.FileName)..."
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

    # Start VM if Start switch is supplied
    If($Start) {
        Write-Host 'Starting Machine...'
        & $VBoxManage startvm $Machine.Name
    }
}

Write-Host "FINISHED!"