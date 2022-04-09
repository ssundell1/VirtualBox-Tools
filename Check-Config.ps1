param(
    [Parameter()][string]$ConfigFile = ".\example.json"
)

# Valid values
## Name -- RegEx
$ValidName = "^[a-zA-Z0-9_]+$"
## Firmware
$ValidFirmware = ("bios","efi","efi32","efi64")
## Memory -- RegEx
$ValidMemory = "^\d+$"
## VideoMemory -- RegEx
$ValidVideoMemory = "^\d+$"
## Storage
### Controllers
$ValidStorageControllerName = "^[a-zA-Z0-9_]+$"
$ValidStorageControllerType = ("ide","sata","scsi","floppy","sas","usb","pcie")
$ValidStorageControllerLogic = ("LSILogic","LSILogicSAS","BusLogic","IntelAhci","PIIX3","PIIX4","ICH6","I82078","USB","NVMe")
$ValidStorageControllerBootable = ("on","off")
#### Attachments
$ValidStorageAttachmentType = ("dvddrive","hdd","fdd")
$ValidStorageAttachmentFileName = "^[a-zA-z0-9_-]+.vmdk$"
$ValidStorageAttachmentSize = "^\d+$"
## NetworkAdapters
$ValidNetworkAdaptersType = ("none","null","nat","natnetwork","bridged","intnet","hostonly","generic")
$ValidNetworkAdaptersConnected = ("on","off")
### BridgeAdapter
$ValidNetworkAdaptersBridgeAdapter = (Get-NetAdapter).InterfaceDescription
### HostOnlyAdapter
$ValidNetworkAdaptersHostOnlyAdapter = (Get-NetAdapter).InterfaceDescription

$ConfigError = $:False

if(!(Test-Path $ConfigFile)) {
    Throw "Could not find config file!"
}
$Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

if([string](Get-Content $ConfigFile) | Test-Json) {
    Write-Host -ForegroundColor Green -Object "Configuration is valid JSON!"
} else {
    Throw "Configuration is not valid JSON! Check your config file."
}

Write-Host "================================================================"
Write-Host "Parsing machines..."
Write-Host "================================================================"

ForEach ($Machine in $Config.Machines) {
    # Verify Name
    Write-Host "Machine:"$Machine.Name
    if($Machine.Name -match $ValidName) {
        Write-Verbose "'$($Machine.Name)' is a valid name"
    } else {
        Write-Host -ForegroundColor Red "'$($Machine.Name)' is an invalid name. Accepted pattern is $ValidName"
        $ConfigError = $:True
    }

    # Verify Firmware
    Write-Host "`tSystem:"$Machine.Firmware
    if($Machine.Firmware -in $ValidFirmware) {
        Write-Verbose "'$($Machine.Firmware)' is a valid firmware"
    } else {
        Write-Host -ForegroundColor Red "`t'$($Machine.Firmware)' is an invalid firmware type. Accepted firmware types are: $ValidFirmware"
        $ConfigError = $:True
    }

    # Verify Memory
    Write-Host "`tMemory:"$Machine.Memory
    if($Machine.Memory -match $ValidMemory) {
        Write-Verbose "'$($Machine.Memory)' is a valid memory value"
    } else {
        Write-Host -ForegroundColor Red "`t'$($Machine.Firmware)' is an invalid memory value. Accepted pattern is: $ValidMemory"
        $ConfigError = $:True
    }

    ForEach($NetworkAdapter in $Machine.NetworkAdapters) {
        # Verify NetworkAdapter Type
        Write-Host "`tNetworkAdapter:"$NetworkAdapter.Type
        if($NetworkAdapter.Type -in $ValidNetworkAdaptersType) {
        Write-Verbose "'$($NetworkAdapter.Type)' is a valid network adapter type"
        } else {
            Write-Host -ForegroundColor Red "`t`t'$($NetworkAdapter.Type)' is an invalid network adapter type. Accepted network adapter types are: $ValidNetworkAdaptersType"
            $ConfigError = $:True
        }

        # Verify NetworkAdapter connection status
        Write-Host "`t`tConnected:"$NetworkAdapter.Connected
        if($NetworkAdapter.Connected -in $ValidNetworkAdaptersConnected) {
        Write-Verbose "'$($NetworkAdapter.Connected)' is a valid network adapter connection state"
        } else {
            Write-Host -ForegroundColor Red "`t`t'$($NetworkAdapter.Connected)' is an invalid network adapter connection state. Accepted network adapter connection states are: $ValidNetworkAdaptersConnected"
            $ConfigError = $:True
        }

        if($NetworkAdapter.Type -eq "bridged") {
            # Verify BridgeAdapter
            Write-Host "`t`tBridgeAdapter:"$NetworkAdapter.BridgeAdapter
            if($NetworkAdapter.BridgeAdapter -in $ValidNetworkAdaptersBridgeAdapter) {
                Write-Verbose "'$($NetworkAdapter.BridgeAdapter)' is a valid network bridge adapter"
            } else {
                Write-Host -ForegroundColor Red "`t`t'$($NetworkAdapter.BridgeAdapter)' could not be found on the system. Did you mean one of these network adapters?" $ValidNetworkAdaptersBridgeAdapter
                $ConfigError = $:True
            } 
        } elseif ($NetworkAdapter.Type -eq "hostonly") {
            # Verify HostAdapter
            Write-Host "`t`tHostOnlyAdapter:"$NetworkAdapter.HostOnlyAdapter
            if($NetworkAdapter.HostOnlyAdapter -in $ValidNetworkAdaptersHostOnlyAdapter) {
                Write-Verbose "'$($NetworkAdapter.HostOnlyAdapter)' is a valid network host only adapter"
            } else {
                Write-Host -ForegroundColor Red "`t`t'$($NetworkAdapter.HostOnlyAdapter)' could not be found on the system. Did you mean one of these network adapters?" $ValidNetworkAdaptersHostOnlyAdapter
                $ConfigError = $:True
            }
        }

    }
    ForEach ($Controller in $Machine.Storage.Controllers) {
        # Verify storage controller name
        Write-Host "`tStorageController:"$Controller.Name
        if($Controller.Name -match $ValidStorageControllerName) {
            Write-Verbose "'$($Controller.Name)' is a valid storage controller name"
        } else {
            Write-Host -ForegroundColor Red "`t'$($Controller.Name)' is not a valid storage controller name. Accepted pattern is: $ValidStorageControllerName"
            $ConfigError = $:True
        }

        # Verify storage controller type
        Write-Host "`t`tType:"$Controller.Type
        if($Controller.Type -in $ValidStorageControllerType) {
            Write-Verbose "'$($Controller.Type)' is a valid storage controller type"
        } else {
            Write-Host -ForegroundColor Red "`t`t'$($Controller.Type)' is not a valid storage controller type. Accepted types are: $ValidStorageControllerType"
            $ConfigError = $:True
        }
        
        # Verify storage controller logic
        Write-Host "`t`tLogic:"$Controller.Logic
        if($Controller.Logic -in $ValidStorageControllerLogic) {
            Write-Verbose "'$($Controller.Logic)' is a valid storage controller logic"
        } else {
            Write-Host -ForegroundColor Red "`t`t'$($Controller.Logic)' is not a valid storage controller logic. Accepted types are: $ValidStorageControllerLogic"
            $ConfigError = $:True
        }

        # Verify storage controller bootable 
        Write-Host "`t`tBootable:"$Controller.Bootable
        if($Controller.Bootable -in $ValidStorageControllerBootable) {
            Write-Verbose "'$($Controller.Bootable)' is a valid storage controller bootable setting"
        } else {
            Write-Host -ForegroundColor Red "`t`t'$($Controller.Bootable)' is not a valid storage controller bootable setting. Accepted settings are: $ValidStorageControllerBootable"
        }

        ForEach($Attachment in $Controller.Attachments) {
            # Verify storage attachment type
            Write-Host "`t`t`tType:"$Attachment.Type
            if($Attachment.Type -in $ValidStorageAttachmentType) {
            Write-Verbose "'$($Attachment.Type)' is a valid storage attachment type"
            } else {
                Write-Host -ForegroundColor Red "`t`t'$($Attachment.Type)' is not a valid storage attachment type. Accepted types are: $ValidStorageAttachmentType"
            }

            # Verify storage attachment file name
            Write-Host "`t`t`tFile:"$Attachment.FileName
            if($Attachment.FileName -ne "") {
                if($Attachment.FileName -match $ValidStorageAttachmentFileName) {
                Write-Verbose "'$($Attachment.Type)' is a valid storage attachment type"
                } else {
                    Write-Host -ForegroundColor Red "`t`t'$($Attachment.Type)' is not a valid storage attachment type. Accepted types are: $ValidStorageAttachmentType"
                }
            } else {
                Write-Warning "Attachment FileName is empty. Will generate hard drive name if size is set."
                if($Attachment.Size -eq "") {
                    Throw "Both FileName and Size can't be empty for storage attachment."
                }
            }

            # Verify storage attachment size
            Write-Host "`t`t`tSize:"$Attachment.Size
            if($Attachment.Size -match $ValidStorageAttachmentSize) {
            Write-Verbose "'$($Attachment.Size)' is a valid storage attachment size"
            } else {
                Write-Host -ForegroundColor Red "`t`t'$($Attachment.Size)' is not a valid storage attachment size. Accepted pattern is: $ValidStorageAttachmentSize"
            }
        }
    }
}

If($ConfigError) {
    Throw "Found errors in configuration. Check output above for information."
} else {
    Write-Host -ForegroundColor Green "Configuration check succeeded!"
}