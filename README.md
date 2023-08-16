# Update PWSH Action

GitHub action and Azure DevOps task to update the cloud runner version of PowerShell to latest, nightly, static, or any other version of PowerShell.

The build hosts of Azure DevOps and GitHub defaults to running the latest LTS version of PowerShell.
In some cases we need, or want, to test or run code using a different version. This is where this action will help you.

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