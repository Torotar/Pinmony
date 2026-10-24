[CmdletBinding()]
param(
    [string]$DevEcoHome = $env:DEVECO_STUDIO_HOME,
    [string]$SdkHome = $env:DEVECO_SDK_HOME
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($DevEcoHome)) {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($SdkHome)) {
        $candidates += Split-Path -Parent $SdkHome
    }
    $ide = Get-Process -Name 'devecostudio64' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ide -and $ide.Path) {
        $candidates += Split-Path -Parent (Split-Path -Parent $ide.Path)
    }
    $installations = Get-ItemProperty -Path @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    ) -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*DevEco Studio*' }
    foreach ($installation in $installations) {
        if ($installation.InstallLocation) { $candidates += $installation.InstallLocation }
    }
    $DevEcoHome = $candidates | Where-Object {
        Test-Path -LiteralPath (Join-Path $_ 'tools\hvigor\bin\hvigorw.bat')
    } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($DevEcoHome)) {
        throw 'DevEco Studio not found. Set DEVECO_STUDIO_HOME or specify -DevEcoHome.'
    }
}
if ([string]::IsNullOrWhiteSpace($SdkHome)) {
    $SdkHome = Join-Path $DevEcoHome 'sdk'
}
$hvigor = Join-Path $DevEcoHome 'tools\hvigor\bin\hvigorw.bat'
$java = Join-Path $DevEcoHome 'jbr'
$node = Join-Path $DevEcoHome 'tools\node'
foreach ($required in @($hvigor, $SdkHome, (Join-Path $java 'bin\java.exe'), (Join-Path $node 'node.exe'))) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing build dependency: $required. Specify -DevEcoHome or -SdkHome."
    }
}

$previousSdk = $env:DEVECO_SDK_HOME
$previousJava = $env:JAVA_HOME
$previousPath = $env:Path
$candidate = $null
Push-Location $PSScriptRoot
try {
    $env:DEVECO_SDK_HOME = $SdkHome
    $env:JAVA_HOME = $java
    $env:Path = $node + ';' + $previousPath

    & $hvigor --mode module -p 'product=default' -p 'module=entry@default' -p 'buildMode=release' -p 'debuggable=false' assembleHap --no-incremental --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "Release build failed (exit code $LASTEXITCODE)." }

    $source = Join-Path $PSScriptRoot 'entry\build\default\outputs\default\entry-default-unsigned.hap'
    $outputDirectory = Join-Path $PSScriptRoot 'release'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $output = Join-Path $outputDirectory 'Pinmony-release-unsigned.hap'
    $candidate = Join-Path $outputDirectory ('release-check-' + [Guid]::NewGuid().ToString('N') + '.hap')
    # Validate a separate copy so a later Debug build cannot replace this artifact.
    Copy-Item -LiteralPath $source -Destination $candidate
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($candidate)
    try {
        $entry = $archive.GetEntry('module.json')
        if ($null -eq $entry) { throw 'HAP is missing module.json.' }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $metadata = $reader.ReadToEnd() | ConvertFrom-Json }
        finally { $reader.Dispose() }
        if ($metadata.app.debug -ne $false -or $metadata.app.buildMode -ne 'release') {
            throw 'Package verification failed: this is not a Release HAP.'
        }
        if ($null -ne $archive.GetEntry('ets/sourceMaps.map')) {
            throw 'Package verification failed: HAP contains Debug source maps.'
        }
    } finally { $archive.Dispose() }
    Move-Item -LiteralPath $candidate -Destination $output -Force

    Write-Host "Verified Release $($metadata.app.versionName) ($($metadata.app.versionCode)), debug=false"
    Write-Host "Unsigned HAP: $output"
    Write-Host "SHA256: $((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash)"
} finally {
    if ($candidate -and (Test-Path -LiteralPath $candidate)) {
        Remove-Item -LiteralPath $candidate
    }
    $env:DEVECO_SDK_HOME = $previousSdk
    $env:JAVA_HOME = $previousJava
    $env:Path = $previousPath
    Pop-Location
}
