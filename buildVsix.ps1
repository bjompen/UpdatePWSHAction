$BaseFolder = $PSScriptRoot

Set-Location $BaseFolder
Get-ChildItem *.vsix | Remove-Item

Push-Location "$BaseFolder\PWSHUpdater"
Get-ChildItem index.js -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
& tsc
Pop-Location

& tfx extension create --manifest-globs vss-extension.json