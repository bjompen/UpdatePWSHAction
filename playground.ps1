
Function Add-PathTToSettings {
    <#
    .Synopsis
        Adds a Path to settings (Supports Windows Only)
    .DESCRIPTION
        Adds the target path to the target registry.
    .Parameter Path
        The path to add to the registry. It is validated with Test-PathNotInSettings which ensures that:
        -The path exists
        -Is a directory
        -Is not in the registry (HKCU or HKLM)
    .Parameter Target
        The target hive to install the Path to.
        Must be either User or Machine
        Defaults to User
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet([System.EnvironmentVariableTarget]::User, [System.EnvironmentVariableTarget]::Machine)]
        [System.EnvironmentVariableTarget] $Target = ([System.EnvironmentVariableTarget]::User)
    )

    if ($Target -eq [System.EnvironmentVariableTarget]::User) {
        [string] $Environment = 'Environment'
        [Microsoft.Win32.RegistryKey] $Key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($Environment, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
    } else {
        [string] $Environment = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
        [Microsoft.Win32.RegistryKey] $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Environment, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
    }

    # $key is null here if it the user was unable to get ReadWriteSubTree access.
    if ($null -eq $Key) {
        throw (New-Object -TypeName 'System.Security.SecurityException' -ArgumentList "Unable to access the target registry")
    }

    # Get current unexpanded value
    [string] $CurrentUnexpandedValue = $Key.GetValue('PATH', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)

    # Keep current PathValueKind if possible/appropriate
    try {
        [Microsoft.Win32.RegistryValueKind] $PathValueKind = $Key.GetValueKind('PATH')
    } catch {
        [Microsoft.Win32.RegistryValueKind] $PathValueKind = [Microsoft.Win32.RegistryValueKind]::ExpandString
    }

    # Evaluate new path
    $NewPathValue = [string]::Concat($CurrentUnexpandedValue.TrimEnd([System.IO.Path]::PathSeparator), [System.IO.Path]::PathSeparator, $Path)

    # Upgrade PathValueKind to [Microsoft.Win32.RegistryValueKind]::ExpandString if appropriate
    if ($NewPathValue.Contains('%')) { $PathValueKind = [Microsoft.Win32.RegistryValueKind]::ExpandString }

    $Key.SetValue("PATH", $NewPathValue, $PathValueKind)
}

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

            $release = $metadata.ReleaseTag -replace '^v'
            $blobName = $metadata.BlobName
        
            if ($IsWindows) {
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
            $blobName = $Version.replace('.','-')
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


    $downloadURL = "https://pscoretestdata.blob.core.windows.net/${blobName}/${packageName}"
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
        New-Item -Path $targetFolder -ItemType Directory
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
    if ($IsWindows) {
        # Remove the current powershell from PATH
        [string] $Environment = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
        [Microsoft.Win32.RegistryKey] $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Environment, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
        $NoPwsh = $key.GetValue('PATH') -split [System.IO.Path]::PathSeparator | Where-Object {$_ -notlike "*\PowerShell\*"}
        $NewPathValue = $($NoPwsh -join [System.IO.Path]::PathSeparator)
        $Key.SetValue("PATH", $NewPathValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        
        # Add new powershell
        $TargetRegistry = [System.EnvironmentVariableTarget]::User
        Add-PathTToSettings -Path $targetFolder -Target $TargetRegistry
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

$DownloadedPwsh = Invoke-PowerShellVersionDownload -ReleaseVersion daily
Install-PowerShellVersion -ArchiveFile $DownloadedPwsh
