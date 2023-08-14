
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
        [string]$architecture = 'x64'
    )

    switch ($PSCmdlet.ParameterSetName) {
        'predefined' { 
            $VersionUri = "https://aka.ms/pwsh-buildinfo-$ReleaseVersion"
            Write-Verbose "Getting version from shortlink: $VersionUri"
            
            $metadata = Invoke-RestMethod  -Uri $VersionUri -Method Get
        
            $release = $metadata.ReleaseTag -replace '^v'
            $blobName = $metadata.BlobName
        
            if ($IsWindows) {
                switch ($env:PROCESSOR_ARCHITECTURE) {
                    'AMD64' { $architecture = 'x64' }
                    'x86' { $architecture = 'x86' }
                    'ARM64' { $architecture = 'arm64' }
                    default { throw "PowerShell package for OS architecture '$_' is not supported." }
                }
                $packageName = "PowerShell-${release}-win-${architecture}.zip"
            }
            elseif ($IsLinux) {
                $unameOutput = uname -m
                switch -Wildcard ($unameOutput) {
                    'x86_64' { $architecture = 'x64' }
                    'aarch64*' { $architecture = 'arm64' }
                    'armv8*' { $architecture = 'arm64' }
                }
                $packageName = "powershell-${release}-linux-${architecture}.tar.gz"
            }
            elseif ($IsMacOS) {
                $unameOutput = uname -m
                switch ($unameOutput) {
                    'x86_64' { $architecture = 'x64' }
                    'arm64' { $architecture = 'arm64' }
                }
                $packageName = "powershell-${release}-osx-${architecture}.tar.gz"
            }
            else {
                throw 'Unknown platform. I dont know how to support this.'
            }
        }
        'static' { 
            if (($OperatingSystem -ne 'win') -and ($architecture -eq 'x86')) {
                throw 'x86 platform is only supported on Windows.'
            }
            $blobName = $Version.replace('.','-')
            if ($blobName -notmatch '^v') {
                $blobName = "v$blobName"
            }

            $release = $Version -replace '^v'
            switch ($OperatingSystem) {
                'win' { $packageName = "PowerShell-${release}-win-${architecture}.zip" }
                'linux' { $packageName = "powershell-${release}-linux-${architecture}.tar.gz" }
                'osx' { $packageName = "powershell-${release}-osx-${architecture}.tar.gz" }
                Default { throw 'Unknown platform. I dont know how to support this.' }
            }
        }
    }


    $downloadURL = "https://pscoretestdata.blob.core.windows.net/${blobName}/${packageName}"
    Write-Verbose "About to download package from '$downloadURL'" -Verbose

    $tempDir = [System.IO.Path]::GetTempPath()    
    $packagePath = Join-Path -Path $tempDir -ChildPath $packageName
    Invoke-WebRequest -Uri $downloadURL -OutFile $packagePath
}



$currentlyInstalledVersion = ((pwsh -version) -split " ")[1]
if($currentlyInstalledVersion -eq $release) {
    Write-Verbose "Requested PowerShell version already installed. Skipping." -Verbose
    return
}