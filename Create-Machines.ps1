param(
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$ConfigFile = ".\config.json",
    [Parameter()][string]$Workspace = "C:\Users\sebas\VirtualMachines"
 )

$Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

Function Get-VM-Info($Config) {
    ForEach ($Machine in $Config.Machines) {
        Write-Host "Machine:"$Machine.Name
        Write-Host "`tSystem:"$Machine.Firmware
        ForEach($NetworkAdapter in $Machine.NetworkAdapaters) {
            Write-Host "`tNetworkAdapater:"$NetworkAdapter.Type
        }
        ForEach ($Controller in $Machine.Storage.Controllers) {
            Write-Host "`tStorageController:"$Controller.Name
            ForEach($Attachment in $Controller.Attachments) {
                Write-Host "`t`tAttachment:"$Attachment.Name
                Write-Host "`t`t`tType:"$Attachment.Type
                Write-Host "`t`t`tFile:"$Attachment.FileName
                Write-Host "`t`t`tSize:"$Attachment.Size
            }
        }
    }
}

Get-VM-Info($Config)

& '.\Clean-Registered-Disks.ps1'

ForEach ($Machine in $Config.Machines) {
    # Create VM
    Write-Host "[+] CREATING MACHINE"$Machine.Name
    & $VBoxManage createvm --name $Machine.Name --register
    # Set firmware
    & $VBoxManage modifyvm $Machine.Name --firmware $Machine.Firmware
    # Set Memory
    & $VBoxManage modifyvm $Machine.Name --memory $Machine.Memory
    # Enable USB 3.0
    & $VBoxManage modifyvm $Machine.Name --usbxhci on

    $NetAdapterIndex = 1
    ForEach($NetworkAdapter in $Machine.NetworkAdapters) {
        # Add Network Adapters
        & $VBoxManage modifyvm $Machine.Name `
            --nic$NetAdapterIndex $NetworkAdapter.Type
        $NetAdapterIndex++
    }

    # Storage Controllers
    ForEach ($Controller in $Machine.Storage.Controllers) {
        # Create storage controllers
        & $VBoxManage storagectl $Machine.Name `
            --name $Controller.Name `
            --add $Controller.Type `
            --controller $Controller.Logic `
            --bootable $Controller.Bootable

        $AttachmentIndex = 0
        ForEach($Attachment in $Controller.Attachments) {
            # Check if file exists
            if(Test-Path($Attachment.FileName)) {
                Write-Host $Attachment.FileName"found. Attaching..."
            } else {
                # If it doesn't exist, create a new virtual hdd
                if($Attachment.Size -ne "") {
                    # Create medium
                    if($Attachment.FileName -eq "") {
                        Throw "No file name found for storage attachment."
                    }
                    $FilePath = Join-Path $Workspace $Machine.Name $Attachment.FileName
                    Write-Host $FilePath
                    & $VBoxManage createmedium disk `
                        --filename $FilePath `
                        --size $Attachment.Size `
                        --format VMDK
                }
            }
            # Create storage attachments
            & $VBoxManage storageattach $Machine.Name `
                --storagectl $Controller.Name `
                --type $Attachment.Type `
                --medium $FilePath `
                --port $AttachmentIndex

            $AttachmentIndex++
        }
    }
}