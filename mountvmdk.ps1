param(
    [Parameter()]
    [String]$Foldername
)

$customMountObject = @()
$fileswithoutSesparse = @()
$fileswithSesparse = @()
$vmdkFiles=Get-ChildItem -Path $Foldername -Recurse -Filter "*.vmdk" | Where-Object { $_.Length -le 2048 } | Select-Object -ExpandProperty FullName
$aim_cli_exe = "C:\Users\User\Downloads\Arsenal-Image-Mounter-v3.10.262\Arsenal-Image-Mounter-v3.10.262\aim_cli.exe"
$provider="DiscUtils"

#$vmdkFiles

foreach ($file in $vmdkFiles) {
    $content = Get-Content -Path $file -ErrorAction SilentlyContinue
    if ($content -imatch 'sesparse'){
        $fileswithSesparse +=$file
        }
        else {
        $fileswithoutSesparse += $file
        }
}

$vmdkFiles=$fileswithoutSesparse


$vmdkFiles | ForEach-Object {
    $Filename = $_
    Write-Host "Starting to mount $Filename"
    
    $diffFile="$Filename.tmp"
    $job = Start-Job -ScriptBlock {param($aim_cli_exe,$Filename,$provider,$diffFile) & $aim_cli_exe --mount=removable --writable --filename=$Filename --provider=$provider --writeoverlay=$diffFile --autodelete --background} -ArgumentList $aim_cli_exe,$Filename,$provider,$diffFile

    # Function to get current drives
    function Get-CurrentDrives {
        Get-PSDrive -PSProvider 'FileSystem' | Select-Object -ExpandProperty Root
    }

    # Initial list of drives
    $initialDrives = Get-CurrentDrives

    # Continuously check for new drives
    while ($true) {
        Start-Sleep -Seconds 5
        $currentDrives = Get-CurrentDrives
        $newDrives = Compare-Object -ReferenceObject $initialDrives -DifferenceObject $currentDrives
        if ($newDrives -and ($newDrives.SideIndicator -eq '=>')) {
            # Write-Host "New drive(s) mounted"
            Start-Sleep -Seconds 2
            break
        } else {
            
            $offlineDisk = Get-Disk | Where-Object OperationalStatus -eq Offline
            Set-Disk -Number $offlineDisk.Number -IsOffline $False
        }
    }

    $output=Receive-job $job
    # Write-Host $output

    if ($output -match "Mounted at") {
        $mountPointRegex = "Mounted at ([A-Z]:\\)"
        $mountPoints = ($output | Select-String -Pattern $mountPointRegex -AllMatches).Matches | ForEach-Object {
        $_.Groups[1].Value} 
        # Write-Host $mountPoints
        } else {
        $tmpMountPoint=@()
        $mountPoints = Get-Partition -DiskNumber $offlineDisk.Number | Select-Object DriveLetter
        $mountPoints | ForEach-Object { $tmpMountPoint += "$($_.DriveLetter):\" }
        $mountPoints = $tmpMountPoint
        }
      

    $dismountCommandRegex = "To dismount, type aim_cli --dismount=(.+)"
    if ("$output" -match $dismountCommandRegex) {
        $dismountCommand = $matches[1]
    } else {
        $dismountCommand = "Not Found"
    }

    $mountPoints | ForEach-Object {
        $windowsFolderPath = Join-Path -Path $_ -ChildPath "Windows"
        if (Test-Path -Path $windowsFolderPath) {
            # Write-Host "Windows drive found at $_ for $Filename"
            $windowsDrives += $_
        } else {
           # Write-Host "$_ not a Windows drive"
        }
    }

    $customMountObject += [PSCUSTOMOBJECT]@{
        filename = $Filename
        driveLetters = $mountPoints
        physicalDrive = $dismountCommand
        windowsDrives = $windowsDrives
    }
    $windowsDrives=""
    
}

$customMountObject

function Create-Folder {
    param(
        [String]$FolderName
    )
    If (Test-Path $FolderName) {
    }
    else {
        New-Item $FolderName -ItemType Directory
    }

}

$customMountObject | ForEach-Object {
    $windowDrive = $_.windowsDrives
    if ($windowDrive.Length -gt 2) {
        Write-Host $windowDrive
        # Starting to run KAPE 
        $kapeExe = "C:\Users\User\Documents\tools\kape\kape.exe"
        $onlyFileName = ls $_.filename | Select-Object Name
        $value =  $onlyFileName.Name
        $hostname = $value.Replace(".vmdk", "")
        Write-Host $hostname
        $outputPath = "C:\Users\User\Documents\tmp\$hostname"
        $targetDest = "$outputPath\target"
        $modulesDest = "$outputPath\modules"
        Write-Host $outputPath
        Write-Host $targetDest
        Write-Host $modulesDest

        Create-Folder $outputPath
        Create-Folder $targetDest
        Create-Folder $modulesDest
        & $kapeExe --tsource $windowDrive --tdest $targetDest --target !BasicCollection,!SANS_Triage,WindowsTimeline --vss --vhdx $hostname --msource $targetDest --mdest $modulesDest --mflush --module !EZParser --mef csv
    } 
}

$customMountObject | ForEach-Object {
    $value = $_.physicalDrive
    & $aim_cli_exe --dismount=$value
}

# Files not supported 
Write-Host "These files are not supported and must be mounted manually"
$fileswithSesparse
