# VirtualBox-Tools

Creates virtual machines based on a JSON configuration file.

## Prerequisites

* Install VirtualBox
* Install VirtualBox Extension Pack

## How To

* Create your json configuration file.
* Make sure your VirtualBox workspace is configured to the location where you want your machines.
* Import module and use the supplied functions:
    1. New-Machines
    2. Remove-Disks
    3. Remove-Machines
    4. Test-Configuration
    5. Test-VmRunning

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