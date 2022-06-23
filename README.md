# VirtualBox-Tools

Creates virtual machines based on a JSON configuration file.

## Prerequisites

* Install VirtualBox
* Install VirtualBox Extension Pack

## How To

* Create your json configuration file.
* Make sure your VirtualBox workspace is configured to the location where you want your machines.
* Run Create-Machines.ps1 with your config file.

## JSON Schema

```
{
    "Machines": [
        {
            "Name": "[string]",
            "Firmware": "bios|efi|efi32|efi64",
            "Memory": "[MB]",
            "VideoMemory": "[MB]",
            "Storage": {
                "Controllers": [
                    {
                        "Name": "[string]",
                        "Type": "ide|sata|scsi|floppy|sas|usb|pcie",
                        "Logic": "LSILogic|LSILogicSAS|BusLogic|IntelAhci|PIIX3|PIIX4|ICH6|I82078|USB|NVMe",
                        "Bootable": "on|off",
                        "Attachments": [
                            {
                                "Type": "dvddrive|hdd|fdd",
                                "FileName": "[string].vmdk",
                                "Size": "[MB]"
                            }
                        ]
                    }
                ]
            },
            "NetworkAdapters": [
                {
                    "Type": "none|null|nat|natnetwork|bridged|intnet|hostonly|generic",
                    "Connected": "on|off",
                    "BridgeAdapter": "[devicename]"
                    "HostOnlyAdapter": "[devicename]"
                }
            ]
        }
    ]
}
```

Array elements can be multiplied:
1. Machines
2. Controllers
3. Attachments
4. NetworkAdapters

## Full Get-Help
```
SYNOPSIS
    Creates VirtualBox virtual machines from command line.


SYNTAX
    C:\Users\sebas\Documents\Git\VirtualBox-Tools\Create-Machines.ps1 [[-VBoxManage] <String>] [[-ConfigFile] <String>] [[-Workspace] <String>] [-Force] [-TurnOn] [<CommonParameters>]


DESCRIPTION
    Creates virtual machines based on a JSON configuration file.


PARAMETERS
    -VBoxManage <String>
        Path to the VBoxManage.exe binary from VirtualBox.
        Default = "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"

        Required?                    false
        Position?                    1
        Default value                C:\Program Files\Oracle\VirtualBox\VBoxManage.exe
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -ConfigFile <String>
        Path to the configuration file with virtual machine specificatins.
        Default = ".\example.json"

        Required?                    false
        Position?                    2
        Default value                .\example.json
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Workspace <String>
        Path to the directory where the virtual machines will be created.
        Default = "C:\VirtualMachines"

        Required?                    false
        Position?                    3
        Default value                C:\VirtualMachines
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Force [<SwitchParameter>]
        Force script to purge any existing virtual machines with the same name as a new machine.
        Default = False

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -TurnOn [<SwitchParameter>]
        Tell VirtualBox to power on the machine after they have been created.
        Default = False

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).
```