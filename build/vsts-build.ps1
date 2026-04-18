<#
This script publishes the module to the gallery.
It expects as input an ApiKey authorized to publish the module.

Insert any build steps you may need to take before publishing it here.
#>
param (
	$ApiKey,

	$WorkingDirectory,

	$Repository = 'PSGallery',

	[switch]
	$SkipPublish,

	[switch]
	$AutoVersion
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory)
{
	if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS)
	{
		$WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
	}
	else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
if (-not $WorkingDirectory) { $WorkingDirectory = Split-Path $PSScriptRoot }
#endregion Handle Working Directory Defaults

# Prepare publish folder
Write-Host "Creating and populating publishing directory: $($publishDir.FullName)"
$publishDir = New-Item -Path $WorkingDirectory -Name publish -ItemType Directory -Force
Copy-Item -Path (Join-Path $WorkingDirectory "ModuleExplorer") -Destination $publishDir.FullName -Recurse -Force

#region Gather text data to compile
$text = @()

# Preserve #Requires from the original psm1 if it exists
$originalPsm1 = Join-Path $WorkingDirectory "ModuleExplorer/ModuleExplorer.psm1"
if (Test-Path $originalPsm1) {
    $psm1Content = Get-Content $originalPsm1
    $requires = $psm1Content | Where-Object { $_ -match '^#Requires' }
    if ($requires) {
        Write-Host "Preserving #Requires statement"
        $text += $requires
        $text += ""
    }
}

# Gather commands
Write-Host "Gathering functions and scripts..."
$internalFunctionsPath = Join-Path $publishDir.FullName "ModuleExplorer/internal/functions/"
if (Test-Path $internalFunctionsPath) {
    Get-ChildItem -Path $internalFunctionsPath -Recurse -File -Filter "*.ps1" | ForEach-Object {
        $text += [System.IO.File]::ReadAllText($_.FullName)
    }
}

$functionsPath = Join-Path $publishDir.FullName "ModuleExplorer/functions/"
if (Test-Path $functionsPath) {
    Get-ChildItem -Path $functionsPath -Recurse -File -Filter "*.ps1" | ForEach-Object {
        $text += [System.IO.File]::ReadAllText($_.FullName)
    }
}

# Gather scripts
$internalScriptsPath = Join-Path $publishDir.FullName "ModuleExplorer/internal/scripts/"
if (Test-Path $internalScriptsPath) {
    Get-ChildItem -Path $internalScriptsPath -Recurse -File -Filter "*.ps1" | ForEach-Object {
        $text += [System.IO.File]::ReadAllText($_.FullName)
    }
}

#region Update the psm1 file & Cleanup
Write-Host "Updating ModuleExplorer.psm1 and cleaning up subdirectories"
$targetPsm1 = Join-Path $publishDir.FullName "ModuleExplorer/ModuleExplorer.psm1"
[System.IO.File]::WriteAllText($targetPsm1, ($text -join "`n`n"), [System.Text.Encoding]::UTF8)

Remove-Item -Path (Join-Path $publishDir.FullName "ModuleExplorer/internal") -Recurse -Force
Remove-Item -Path (Join-Path $publishDir.FullName "ModuleExplorer/functions") -Recurse -Force
#endregion Update the psm1 file & Cleanup

#region Updating the Module Version
if ($AutoVersion)
{
	Write-Host  "Updating module version numbers."
	try { [version]$remoteVersion = (Find-Module 'ModuleExplorer' -Repository $Repository -ErrorAction Stop).Version }
	catch
	{
		throw "Failed to access $($Repository) : $_"
	}
	if (-not $remoteVersion)
	{
		throw "Couldn't find ModuleExplorer on repository $($Repository) : $_"
	}
	$newBuildNumber = $remoteVersion.Build + 1
	[version]$localVersion = (Import-PowerShellDataFile -Path (Join-Path $publishDir.FullName "ModuleExplorer/ModuleExplorer.psd1")).ModuleVersion
	Update-ModuleManifest -Path (Join-Path $publishDir.FullName "ModuleExplorer/ModuleExplorer.psd1") -ModuleVersion "$($localVersion.Major).$($localVersion.Minor).$($newBuildNumber)"
}
#endregion Updating the Module Version

#region Publish
if ($SkipPublish) { return }

# Publish to Gallery
Write-Host  "Publishing the ModuleExplorer module to $($Repository)"
Publish-Module -Path (Join-Path $publishDir.FullName "ModuleExplorer") -NuGetApiKey $ApiKey -Force -Repository $Repository
#endregion Publish