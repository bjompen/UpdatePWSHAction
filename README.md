# Update PWSH Action

GitHub action and Azure DevOps task to update the cloud runner version of PowerShell to latest, nightly, static, or any other version of PowerShell.

The build hosts of Azure DevOps and GitHub defaults to running the latest LTS version of PowerShell.
In some cases we need, or want, to test or run code using a different version. This is where this action will help you.

> Most, not all, of the PowerShell code here is stolen and adapted from [install-powershell.ps1 on PowerShell GitHub](https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.ps1).
> 
> The Azure DevOps Task was created with _a lot_ of help from [Barbara Forbes](https://4bes.nl/2021/02/21/create-a-custom-azure-devops-powershell-task/) blog post on the subject. 

## Usage

### GitHub action

```Yaml
- uses: bjompen/UpdatePWSHAction@version
  with:
    ReleaseVersion: 'Preview'
```

This will install latest Preview version of PowerShell.

_or_

```Yaml
- uses: bjompen/UpdatePWSHAction@version
  with:
    FixedVersion: '7.1.0'
```

This will install version 7.1.0 of PowerShell.

While it is technically possible to set both Fixed and Release version, Fixed will take precedence.

```Yaml
- uses: bjompen/UpdatePWSHAction@version
  with:
    FixedVersion: '7.1.0'
    ReleaseVersion: 'Preview'
```

This will install version 7.1.0 of PowerShell.

> Setting a FixedVersion requires you to know this version exists. If you input a non released version this step will fail with weird errors.

### Azure DevOps

Go to the [Azure DevOps Marketplace](https://marketplace.visualstudio.com/azuredevops) and search, or go to [my publisher page](https://marketplace.visualstudio.com/publishers/Bjompen) and find it there.

Add it to your pipeline using the snippet

```yaml
- task: PWSHUpdater@0
# This will install the latest Stable release

- task: PWSHUpdater@0
  inputs:
    ReleaseVersion: 'daily'
# This will install the latest Daily release

- task: PWSHUpdater@0
  inputs:
    FixedVersion: '7.1.0'
# This will install pwsh version 7.1.0
```

Please note that FixedVersion will take precedence!

```yaml
- task: PWSHUpdater@0
  inputs:
    ReleaseVersion: 'daily'
    FixedVersion: '7.1.0'
# This will install pwsh version 7.1.0
```
