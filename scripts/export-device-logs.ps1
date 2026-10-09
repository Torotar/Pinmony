param(
  [string]$HdcPath = 'hdc',
  [string]$Destination = (Join-Path $PSScriptRoot ('../diagnostics/' + (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
$ErrorActionPreference = 'Stop'
$targetDirectory = [System.IO.Path]::GetFullPath($Destination)
New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
$copied = 0
foreach ($name in @('pinweb-session-current.log', 'pinweb-session-previous.log', 'pinweb-runtime.log')) {
  # The UIAbility filesDir belongs to the entry module, not application-level base/files.
  $remotePath = './data/storage/el2/base/haps/entry/files/' + $name
  $localPath = Join-Path $targetDirectory $name
  $result = & $HdcPath file recv -b com.pinweb.app $remotePath $localPath 2>&1
  if ($LASTEXITCODE -eq 0 -and ($result -join '') -notmatch '\[Fail\]' -and (Test-Path -LiteralPath $localPath)) {
    $copied++
    Write-Output $localPath
  } else {
    Write-Warning ('Log unavailable: ' + $name)
  }
}
if ($copied -eq 0) { throw 'No logs retrieved. Connect a USB-debugging device with the debug build installed.' }
