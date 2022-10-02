Function New-Machines() {
    <#
        .SYNOPSIS
        Creates VirtualBox virtual machines from command line.

        .DESCRIPTION
        Creates virtual machines based on a JSON configuration file.

        .PARAMETER ConfigFile
        Path to the configuration file with virtual machine specificatins.
        Default = ".\example.json"

        .PARAMETER Force
        Force script to purge any existing virtual machines with the same name as a new machine.
        Default = False

        .PARAMETER Start
        Tell VirtualBox to power on the machine after they have been created.
        Default = False

        .INPUTS
        None. You cannot pipe objects to Create-Machines.

        .OUTPUTS
        None.
    #>
    param(
    [Parameter()][string]$ConfigFile,
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$Workspace = "C:\VirtualMachines",
    [Parameter()][switch]$Force,
    [Parameter()][switch]$Start
    )

    if($ConfigFile -eq "") {
        Throw "No configuration (-ConfigFile) file supplied. See example.json"
    }

    if(!(Test-Path $ConfigFile)) {
        Throw "Could not find config file!"
    }
    $Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

    # Test the supplied configuration.
    Test-Configuration -ConfigFile $ConfigFile

    # Remove any already existing machines if Force flag is set.
    If($Force) {
        Remove-Machines -ConfigFile $ConfigFile -Force
    } Else {
        Remove-Machines -ConfigFile $ConfigFile
    }

    # Clean any hanging disks.
    If($Force) { 
        Remove-Disks -ConfigFile $ConfigFile
    }

    Write-Host "NEW MACHINES"

    ForEach ($Machine in $Config.Machines) {
        # Create VM
        Write-Host "[>] $($Machine.Name)"
        & $VBoxManage createvm --name $Machine.Name --basefolder $Workspace --register > $null
        # Set firmware
        Write-Host "`t[-] Set Firmare"
        Write-Host "`t`t[$($Machine.Firmware)]"
        & $VBoxManage modifyvm $Machine.Name --firmware $Machine.Firmware > $null
        # Set Memory
        Write-Host "`t[-] Set Memory"
        Write-Host "`t`t[$($Machine.Memory) MB]"
        & $VBoxManage modifyvm $Machine.Name --memory $Machine.Memory > $null
        # Set VideoMemory
        Write-Host "`t[-] Set VideoMemory"
        Write-Host "`t`t[$($Machine.VideoMemory) MB]"
        & $VBoxManage modifyvm $Machine.Name --vram $Machine.VideoMemory > $null
        # Enable USB 3.0
        Write-Host "`t[-] Enable USB 3.0"
        & $VBoxManage modifyvm $Machine.Name --usbxhci on > $null

        $NetAdapterIndex = 1
        Write-Host "`t[-] Add Network Adapters"
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
        Write-Host "`t[-] Create storage controllers"
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
                Write-Host "`t[-] Handle attachments"
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
                        $FilePath = Join-Path -Path $Workspace -ChildPath $Machine.Name
                        $FilePath = Join-Path -Path $FilePath -ChildPath $Attachment.FileName
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
            Write-Host -ForegroundColor Green -Object "`t[-] Success!"
        } else {
            Write-Host -ForegroundColor Red -Object "`t[-] Failed!"
        }

        # Start VM if Start switch is supplied
        If($Start) {
            Write-Host "`t[!] Starting Machine..."
            & $VBoxManage startvm $Machine.Name
        }
    }
    Write-Host "FINISHED!"
}

function Remove-Disks() {
    param(
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$ConfigFile
    )

    $Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

    $ListHddsRaw = & $VBoxManage list hdds

    $Location = $ListHddsRaw | findstr '^Location'
    If($Location) {
        $Location = $Location.Split("Location:")
        $Location = $Location.Split('',[System.StringSplitOptions]::RemoveEmptyEntries)

        $UUID = $ListHddsRaw | findstr '^UUID:'
        $UUID = $UUID.Split("UUID:")
        $UUID = $UUID.Split('',[System.StringSplitOptions]::RemoveEmptyEntries)

        Write-Host "REMOVING DISKS"

        $DeletedDisks = $:False
        ForEach($Machine in $Config.Machines) {
            for($i=0;$i -lt $Location.Length;$i++) {
                If($Location[$i] -match $Machine.Name) {
                    Write-Host "Deleting disk:"$UUID[$i].Trim()
                    & $VBoxManage closemedium disk $UUID[$i].Trim()
                    $DeletedDisks = $:True
                }
            }
        }
    }

    If(!$DeletedDisks) {
        Write-Host "No disks to delete"
    }

    Write-Host -ForegroundColor Green -Object "Finished!"
}

function Remove-Machines() {
    param(
        [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
        [Parameter()][string]$ConfigFile,
        [Parameter()][switch]$Force,
        [Parameter()][string]$Workspace = "C:\VirtualMachines"
    )

    $Config = Get-Content $ConfigFile -Raw | ConvertFrom-JSON

    $RegisteredMachines = & $VBoxManage list vms

    Write-Host "DELETING MACHINES"

    ForEach($Machine in $Config.Machines) {
        Write-Host "[>] $($Machine.Name)"
        if($RegisteredMachines -match $Machine.Name) {
            Write-Host "`t[-] Machine $($Machine.Name) is registered in VirtualBox."
            If($Force) {
                Write-Host "`t[-] Force flag set. Unregistering VM..." -ForegroundColor Yellow
                & $VBoxManage unregistervm $Machine.Name > $null
            } Else {
                Write-Warning "Force flag is not set. Will leave registered VM alone."
            }
        } else {
            Write-Host "`t[-] Machine $($Machine.Name) is not registered in VirtualBox."
        }
        if(Test-Path (Join-Path -Path $Workspace -Child $Machine.Name)) {
            Write-Host "`t[-] Machine $($Machine.Name) still has files."
            If($Force) {
                Write-Host "`t[-] Force flag set. Deleting VM files..."
                Remove-Item (Join-Path -Path $Workspace -ChildPath $Machine.Name) -Recurse -Force > $null
            } Else {
                Write-Warning "Force flag is not set. Will leave existing VM files."
                Throw "Use Force flag to remove existing VMs"
            }
        } else {
            Write-Host "`t[-] Machine $($Machine.Name) does not have any residual files."
        }

        $RegisteredMachines = & $VBoxManage list vms
        if($RegisteredMachines -match $Machine.Name) {
            Write-Host -ForegroundColor Red -Object "`t[-] Failed to delete!"
        } else {
            Write-Host -ForegroundColor Green -Object "`t[-] Success!"
        }
    }
}

Function Test-Configuration() {
    param(
    [Parameter()][string]$ConfigFile,
    [Parameter()][string]$VBoxManage = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe",
    [Parameter()][string]$Workspace = "C:\VirtualMachines"
    )

    # Valid settings
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
    $ValidStorageAttachmentSize = "^\d*$"
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

    Write-Host "TEST CONFIGURATION"

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
                $ConfigError = $:True
            }

            ForEach($Attachment in $Controller.Attachments) {
                # Verify storage attachment type
                Write-Host "`t`t`tType:"$Attachment.Type
                if($Attachment.Type -in $ValidStorageAttachmentType) {
                Write-Verbose "'$($Attachment.Type)' is a valid storage attachment type"
                } else {
                    Write-Host -ForegroundColor Red "`t`t'$($Attachment.Type)' is not a valid storage attachment type. Accepted types are: $ValidStorageAttachmentType"
                    $ConfigError = $:True
                }

                # Verify storage attachment file name
                Write-Host "`t`t`tFile:"$Attachment.FileName
                if($Attachment.FileName -ne "") {
                    if($Attachment.FileName -match $ValidStorageAttachmentFileName) {
                    Write-Verbose "'$($Attachment.Type)' is a valid storage attachment type"
                    } else {
                        Write-Host -ForegroundColor Red "`t`t'$($Attachment.Type)' is not a valid storage attachment type. Accepted types are: $ValidStorageAttachmentType"
                        $ConfigError = $:True
                    }
                } else {
                    Write-Warning "Attachment FileName is empty. Will generate hard drive name if size is set."
                    if($Attachment.Size -eq "") {
                        Throw "Both FileName and Size can't be empty for storage attachment."
                        $ConfigError = $:True
                    }
                }

                # Verify storage attachment size
                Write-Host "`t`t`tSize:"$Attachment.Size
                if($Attachment.Size -match $ValidStorageAttachmentSize) {
                Write-Verbose "'$($Attachment.Size)' is a valid storage attachment size"
                } else {
                    Write-Host -ForegroundColor Red "`t`t'$($Attachment.Size)' is not a valid storage attachment size. Accepted pattern is: $ValidStorageAttachmentSize"
                    $ConfigError = $:True
                }
            }
        }
    }

    If($ConfigError) {
        Throw "Found errors in configuration. Check output above for information."
    } else {
        Write-Host -ForegroundColor Green "Configuration check succeeded!"
    }
}

function Test-VmRunning() {
    <#
        .SYNOPSIS
        Checks status of a VirtualBox VM.
        .DESCRIPTION
        Checks status of a VirtualBox VM. Uses VBoxManage to get the status. Returns true if VM has state 'running' and return false if VM has state 'powered off'
        .PARAMETER Name
        Name of the VM
        .PARAMETER VboxManageExecutable
        Path to VBoxManage.exe
        .EXAMPLE
        Test-VmRunning.ps1 -Name 'MyFantasticVm'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,
        [Parameter()]
        [string]
        $VboxManageExecutable = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
    )

    if(-not(Test-Path -Path $VboxManageExecutable -PathType Leaf)) {
        Write-Error -Message "$VboxManageExecutable not found." -ErrorAction Stop
    }

    [array]$result = & $VboxManageExecutable showvminfo $Name
    if($? -eq $true) {
        $State = $result | Select-String -SimpleMatch 'State:'
        $SplitState = $State.Line.Split(" ")
        Switch ($SplitState[-3]) {
            "Running" { $true }
            "off" { $false }
            default { Write-Error -Message "Unable to determind status of VM $Name"}

        }
    } else {
        Write-Error -Message "VM $Name does not exist." -ErrorAction Stop
    }
}

Export-ModuleMember -Function *