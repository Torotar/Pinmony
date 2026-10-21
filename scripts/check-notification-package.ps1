param([string]$Hap = "$PSScriptRoot/../entry/build/default/outputs/default/entry-default-unsigned.hap")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Hap))
try {
  foreach ($item in @(
    @{ Path = 'ets/modules.abc'; Required = @('pm_notify_description_', 'permissions-biz', 'pm_notify_group_delivery'); Forbidden = @('pm_notify_comments_description', 'pm_notify_search_description', 'pm_notify_how') },
    @{ Path = 'resources.index'; Required = @('Get updates about activity on Shuffles', 'How you get notifications', 'Pinterest will still send you important updates about your account'); Forbidden = @() }
  )) {
    $entry = $archive.GetEntry($item.Path)
    if (!$entry) { throw "Missing package entry: $($item.Path)" }
    $stream = $entry.Open()
    $buffer = New-Object IO.MemoryStream
    try { $stream.CopyTo($buffer); $content = [Text.Encoding]::UTF8.GetString($buffer.ToArray()) }
    finally { $stream.Dispose(); $buffer.Dispose() }
    foreach ($value in $item.Required) {
      if (!$content.Contains($value)) { throw "Stale notification package: $($item.Path) missing $value" }
    }
    foreach ($value in $item.Forbidden) {
      if ($content.Contains($value)) { throw "Stale notification package: $($item.Path) contains $value" }
    }
  }
  Write-Output 'Notification package: current description mapping, delivery titles and English resources verified'
} finally { $archive.Dispose() }
