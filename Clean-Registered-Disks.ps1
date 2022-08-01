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

    Write-Host '================================================================'
    Write-Host 'Cleaning registered disks...'
    Write-Host '================================================================'

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