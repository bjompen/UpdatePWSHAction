[string]$ReleaseVersion = Get-VstsInput -Name ReleaseVersion
[string]$FixedVersion = Get-VstsInput -Name FixedVersion

. "$PSScriptRoot/UpgradePwsh.ps1"

if (-not ( [string]::IsNullOrEmpty("$FixedVersion") ) ) {
  Write-Host "Trying to install fixed PowerShell version $FixedVersion"

  if ($IsLinux) {
    $OS = 'linux'
    $unameOutput = uname -m
      switch -Wildcard ($unameOutput) {
        'x86_64' { $architecture = 'x64' }
        'aarch64*' { $architecture = 'arm64' }
        'armv8*' { $architecture = 'arm64' }
      }
  }
  elseif ($IsMacOS) {
    $OS = 'osx'
    $unameOutput = uname -m
      switch ($unameOutput) {
        'x86_64' { $architecture = 'x64' }
        'arm64' { $architecture = 'arm64' }
      }
  }
  elseif (($IsWindows) -or (-not ([string]::IsNullOrEmpty("$env:ProgramFiles")))) {
    $OS = 'win'
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { $architecture = 'x64' }
        'x86' { $architecture = 'x86' }
        'ARM64' { $architecture = 'arm64' }
        default { throw "PowerShell package for OS architecture '$_' is not supported." }
    }
  }

  $DownloadedPwsh = Invoke-PowerShellVersionDownload -Version $FixedVersion -OperatingSystem $OS -Architecture $architecture -Verbose
}
else {
  Write-Host "Installing PowerShell version $ReleaseVersion"
  $DownloadedPwsh = Invoke-PowerShellVersionDownload -ReleaseVersion $ReleaseVersion -Verbose
}

Install-PowerShellVersion -ArchiveFile $DownloadedPwsh -Verbose