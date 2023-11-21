param(
    [Parameter()]
    [String]$Foldername
)

$vhdxFiles=Get-ChildItem -Path $Foldername -Recurse -Filter "*.vhdx" | Select-Object -ExpandProperty FullName

# Write-Host $vhdxFiles

$customMountObject = @()

function Create-Folder {
    param([String]$FolderName)
    If ($tmp=Test-Path $FolderName) {} else {$tmp=New-Item $FolderName -ItemType Directory}
    }

foreach ($vhdxfile in $vhdxfiles) {
    Write-Host $vhdxfile
    $mountedImage = Mount-DiskImage $vhdxfile
    $diskNumber = ($mountedImage | Get-Disk).Number
    $driveLetter = (Get-Partition -DiskNumber $diskNumber | Where-Object { $_.Type -eq 'basic' -or $_.Type -eq 'IFS' }).DriveLetter
    
    # Starting to run KAPE 
        $kapeExe = "C:\Users\User\Documents\tools\kape\kape.exe"
        $onlyFileName = ls $vhdxfile | Select-Object Name
        $value =  $onlyFileName.Name
        $hostname = $value.Replace(".vhdx", "")
        Write-Host $hostname
        $outputPath = "C:\Users\User\Documents\tmp\$hostname"
        $targetDest = "$outputPath\target"
        $modulesDest = "$outputPath\modules"

        Create-Folder $outputPath
        Create-Folder $targetDest
        Create-Folder $modulesDest

        $subDriveLetter = (Get-ChildItem F:\ | Where-Object {$_.Name.Length -eq 1}).Name
        & $kapeExe --tsource $driveLetter":\$subDriveLetter" --tdest $targetDest --target EventLogs --vss --vhdx $hostname --msource $targetDest --mdest $modulesDest --mflush --module hayabusa_Csvtimeline --mef csv

        #& $kapeExe --tsource $driveLetter":\C" --tdest $targetDest --target !BasicCollection,!SANS_Triage,WindowsTimeline --vss --vhdx $hostname --msource $targetDest --mdest $modulesDest --mflush --module !EZParser --mef csv

    $dismountedImage = disMount-DiskImage $vhdxfile
}
