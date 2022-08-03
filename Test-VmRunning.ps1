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
    Write-Error -Message "VM $Name does not exists." -ErrorAction Stop
}