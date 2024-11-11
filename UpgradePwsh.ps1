
function Invoke-PowerShellVersionDownload {
    [CmdletBinding(DefaultParameterSetName = 'predefined')]
    param (
        [Parameter(ParameterSetName = 'predefined')]
        [ValidateSet('daily', 'stable', 'lts', 'preview')]
        [string]$ReleaseVersion = 'stable',

        [Parameter(ParameterSetName = 'static', Mandatory)]
        [string]$Version,

        [Parameter(ParameterSetName = 'static', Mandatory)]
        [ValidateSet('win', 'linux', 'osx')]
        [string]$OperatingSystem,
        
        [Parameter(ParameterSetName = 'static')]
        [ValidateSet('x64', 'x86', 'arm64')]
        [string]$Architecture = 'x64'
    )

    switch ($PSCmdlet.ParameterSetName) {
        'predefined' { 
            $versionUri = "https://aka.ms/pwsh-buildinfo-$ReleaseVersion"
            Write-Verbose "Getting version from shortlink: $versionUri"
            
            $metadata = Invoke-RestMethod  -Uri $versionUri -Method Get
            
            Write-Verbose $metadata

            $blobName = $metadata.ReleaseTag
            $release = $metadata.ReleaseTag -replace '^v'
        
            if (($IsWindows) -or (-not ([string]::IsNullOrEmpty("$env:ProgramFiles")))) {
                switch ($env:PROCESSOR_ARCHITECTURE) {
                    'AMD64' { $architecture = 'x64' }
                    'x86' { $architecture = 'x86' }
                    'ARM64' { $architecture = 'arm64' }
                    default { throw "PowerShell package for OS architecture '$_' is not supported." }
                }
                $packageName = "PowerShell-$release-win-$architecture.zip"
            }
            elseif ($IsLinux) {
                $unameOutput = uname -m
                switch -Wildcard ($unameOutput) {
                    'x86_64' { $architecture = 'x64' }
                    'aarch64*' { $architecture = 'arm64' }
                    'armv8*' { $architecture = 'arm64' }
                }
                $packageName = "powershell-$release-linux-$architecture.tar.gz"
            }
            elseif ($IsMacOS) {
                $unameOutput = uname -m
                switch ($unameOutput) {
                    'x86_64' { $architecture = 'x64' }
                    'arm64' { $architecture = 'arm64' }
                }
                $packageName = "powershell-$release-osx-$architecture.tar.gz"
            }
            else {
                throw 'Unknown platform. I dont know how to support this.'
            }
        }
        'static' { 
            if (($OperatingSystem -ne 'win') -and ($Architecture -eq 'x86')) {
                throw 'x86 platform is only supported on Windows.'
            }
            $blobName = $Version
            if ($blobName -notmatch '^v') {
                $blobName = "v$blobName"
            }

            $release = $Version -replace '^v'
            switch ($OperatingSystem) {
                'win' { $packageName = "PowerShell-$release-win-$Architecture.zip" }
                'linux' { $packageName = "powershell-$release-linux-$Architecture.tar.gz" }
                'osx' { $packageName = "powershell-$release-osx-$Architecture.tar.gz" }
                Default { throw 'Unknown platform. I dont know how to support this.' }
            }
        }
    }


    $downloadURL = "https://github.com/PowerShell/PowerShell/releases/download/${blobName}/${packageName}"
    
    Write-Verbose "About to download package from '$downloadURL'"

    $tempDir = [System.IO.Path]::GetTempPath()
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Invoke-WebRequest -Uri $downloadURL -OutFile $packagePath
    Get-Item $packagePath
}

function Install-PowerShellVersion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.FileInfo]$ArchiveFile,

        [Parameter()]
        [switch]$SkipPath
    )

    $targetFolder = Join-Path -Path (Resolve-Path ~).Path -ChildPath $($ArchiveFile.BaseName -replace '\.tar$')
    if (-not (Test-Path $targetFolder)) {
        $null = New-Item -Path $targetFolder -ItemType Directory
    }

    if ($ArchiveFile.Extension -eq '.zip') {
        Write-Verbose "$($ArchiveFile.Name) is a zip file."
        Expand-Archive -Path $ArchiveFile -DestinationPath $targetFolder
    }
    elseif ($ArchiveFile.Extension -eq '.gz') {
        Write-Verbose "$($ArchiveFile.Name) is a tar file."
        $null = tar zxf $ArchiveFile.FullName -C $targetFolder
    }
    else {
        throw 'Unknown file. I dont know how to extract and install this.'
    }

    # Installation stuff.
    if (($IsWindows) -or (-not ([string]::IsNullOrEmpty("$env:ProgramFiles")))) {
        Write-Verbose "Installing PWSH"
        try {
            if (Test-Path "$env:ProgramFiles\PowerShell\7") {
                Remove-Item "$env:ProgramFiles\PowerShell\7" -Recurse -Force
            }
            Copy-Item -Path "$targetFolder\" -Destination "$env:ProgramFiles\PowerShell\7\" -Recurse
        }
        catch {
            throw "failed to copy totarget folder. Are you currently running pwsh.exe? Cant replace locked files!"
        }
    }
    if ($IsLinux) {
        $targetFullPath = Join-Path -Path $targetFolder -ChildPath "pwsh"
        $null = chmod 755 $targetFullPath
        $symlink = "/usr/bin/pwsh"

        $Uid = id -u
        if ($Uid -ne "0") { $SUDO = "sudo" } else { $SUDO = "" }
        # Make symbolic link point to installed path
        & $SUDO ln -fs $targetFullPath $symlink
    }
    if ($IsMacOS) {
        # This is not tested and verified. Use at your own risk.
        $targetFullPath = Join-Path -Path $targetFolder -ChildPath "pwsh"
        $null = chmod 755 $targetFullPath
        $symlink = "/usr/local/bin/pwsh"

        $Uid = id -u
        if ($Uid -ne "0") { $SUDO = "sudo" } else { $SUDO = "" }
        # Make symbolic link point to installed path
        & $SUDO ln -fs $targetFullPath $symlink
    }
    
}
