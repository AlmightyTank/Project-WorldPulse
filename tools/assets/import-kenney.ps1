<#
.SYNOPSIS
Imports selected Kenney CC0 assets into the Godot project.

.DESCRIPTION
Verifies the source archives against tools/assets/kenney-packs.json, extracts
them to a temp directory, copies the selected models and shared texture, keeps
the original License.txt, converts the animated protagonist FBX set to GLB with
Blender, and writes manifest.json.

.EXAMPLE
$env:KENNEY_ARCHIVE_DIR = "D:\assets\kenney"
npm run assets:import
#>
param(
  [string]$ArchiveDir = $env:KENNEY_ARCHIVE_DIR,
  [string]$Blender = $env:BLENDER_EXE
)

$ErrorActionPreference = "Stop"
function Write-Utf8($Path, $Text) {
  [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$packsFile = Join-Path $PSScriptRoot "kenney-packs.json"
$selectionFile = Join-Path $PSScriptRoot "kenney-selection.json"
$packs = Get-Content $packsFile -Raw | ConvertFrom-Json
$selection = Get-Content $selectionFile -Raw | ConvertFrom-Json
$targetRoot = Join-Path $repo $selection.target_root

if (-not $ArchiveDir) { throw "Set -ArchiveDir or KENNEY_ARCHIVE_DIR to the folder holding the Kenney zip files." }
if (-not (Test-Path $ArchiveDir)) { throw "Archive folder not found: $ArchiveDir" }

$work = Join-Path $env:TEMP "worldpulse-kenney-import"
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force $work, $targetRoot | Out-Null

$packState = @{}
foreach ($pack in $packs.packs) {
  if (-not $pack.models_root) {
    Write-Host "SKIP  $($pack.slug) (no 3D models)"
    continue
  }
  $archive = Join-Path $ArchiveDir $pack.archive
  if (-not (Test-Path $archive)) { throw "Missing archive: $archive" }
  $hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
  if ($hash -ne $pack.sha256) { throw "SHA-256 mismatch for $($pack.archive): expected $($pack.sha256), got $hash" }
  $out = Join-Path $work $pack.slug
  Expand-Archive $archive -DestinationPath $out -Force
  $packState[$pack.slug] = $out

  $packDir = Join-Path $targetRoot $pack.slug
  New-Item -ItemType Directory -Force (Join-Path $packDir "models") | Out-Null
  Copy-Item (Join-Path $out $pack.license_file) (Join-Path $packDir "LICENSE.txt") -Force
  [ordered]@{
    name = $pack.name; version = $pack.version; author = $pack.author
    source_url = $pack.source_url; archive = $pack.archive; sha256 = $pack.sha256
    license = $packs.license.id; license_url = $packs.license.url
  } | ConvertTo-Json | ForEach-Object { Write-Utf8 (Join-Path $packDir "source.json") $_ }
}

$entries = @()
foreach ($asset in $selection.assets) {
  $pack = $packs.packs | Where-Object slug -eq $asset.pack
  $packDir = Join-Path $targetRoot $asset.pack
  $dst = Join-Path $packDir "models\$($asset.id).glb"

  if ($asset.source -like "generated:*") {
    $entries += [pscustomobject]@{ asset = $asset; path = $dst; generated = $true }
    continue
  }
  if (-not $pack.models_root) { throw "Asset $($asset.id) belongs to a pack without 3D models" }
  $src = Join-Path $packState[$asset.pack] $asset.source
  if (-not (Test-Path $src)) { throw "Missing source model for $($asset.id): $src" }
  Copy-Item $src $dst -Force
  if ($pack.texture) {
    $texSrc = Join-Path $packState[$asset.pack] $pack.texture
    $texDir = Join-Path $packDir "models\Textures"
    New-Item -ItemType Directory -Force $texDir | Out-Null
    Copy-Item $texSrc (Join-Path $texDir "colormap.png") -Force
  }
  $entries += [pscustomobject]@{ asset = $asset; path = $dst; generated = $false }
}

$generated = $entries | Where-Object generated
if ($generated) {
  if (-not $Blender) {
    $candidate = Get-ChildItem "C:\Program Files\Blender Foundation" -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1
    if ($candidate) { $Blender = Join-Path $candidate.FullName "blender.exe" }
  }
  if (-not $Blender -or -not (Test-Path $Blender)) { throw "Blender not found. Set -Blender or BLENDER_EXE to convert the protagonist FBX set." }

  $jobs = foreach ($entry in $generated) {
    $packRoot = $packState[$entry.asset.pack]
    [ordered]@{
      model = Join-Path $packRoot $entry.asset.source.Substring(10)
      skin = Join-Path $packRoot $entry.asset.skins
      animations = Join-Path $packRoot "Animations"
      out = $entry.path
    }
  }
  $jobsFile = Join-Path $work "character-jobs.json"
  ForEach-Object -InputObject (ConvertTo-Json @($jobs) -Depth 4) { Write-Utf8 $jobsFile $_ }
  $ErrorActionPreference = "Continue"
  $blenderLog = & $Blender -b --factory-startup --python (Join-Path $PSScriptRoot "convert-characters.py") -- $jobsFile 2>&1
  $ErrorActionPreference = "Stop"
  $blenderLog | ForEach-Object { Write-Host $_ }
  if ($LASTEXITCODE -ne 0) { throw "Blender character conversion failed with exit code $LASTEXITCODE" }
  if ($blenderLog -match 'Traceback \(most recent call last\)') { throw "Blender character conversion raised a Python error. See the log above." }

  foreach ($entry in $generated) {
    if (-not (Test-Path $entry.path)) { throw "Conversion produced no GLB for $($entry.asset.id)" }
    $bytes = [IO.File]::ReadAllBytes($entry.path)
    $jsonLength = [BitConverter]::ToUInt32($bytes, 12)
    $gltf = [Text.Encoding]::UTF8.GetString($bytes, 20, $jsonLength) | ConvertFrom-Json
    $clips = @($gltf.animations | ForEach-Object { $_.name })
    foreach ($expected in $entry.asset.animations) {
      if ($clips -notcontains $expected) {
        throw "Converted $($entry.asset.id) is missing animation '$expected' (found: $($clips -join ', '))"
      }
      $animation = $gltf.animations | Where-Object name -eq $expected | Select-Object -First 1
      $mostKeys = ($animation.samplers | ForEach-Object { $gltf.accessors[$_.input].count } | Measure-Object -Maximum).Maximum
      if ($mostKeys -lt 2) {
        throw "Converted $($entry.asset.id) animation '$expected' has one key per track (bind pose only)"
      }
    }
  }
}

$final = @()
foreach ($entry in $entries) {
  $asset = $entry.asset
  if (-not (Test-Path $entry.path)) { throw "Import missing for $($asset.id): $($entry.path)" }
  $godotRoot = Join-Path $repo "game\godot"
  $relative = $entry.path.Substring($godotRoot.Length + 1) -replace '\\', '/'
  $record = [ordered]@{
    id = $asset.id
    pack = $asset.pack
    category = $asset.category
    source_file = $asset.source
    imported_path = $relative
    sha256 = (Get-FileHash $entry.path -Algorithm SHA256).Hash.ToLower()
    bytes = (Get-Item $entry.path).Length
    license = $packs.license.id
    collision = [bool]$asset.collision
    scale = if ($asset.scale) { [double]$asset.scale } else { [double]$selection.normalization.category_scale.($asset.category) }
  }
  if ($asset.skins) { $record.skin_source = $asset.skins; $record.animations = $asset.animations }
  $final += $record
}

[ordered]@{
  generated_by = "tools/assets/import-kenney.ps1"
  license = $packs.license
  packs = @($packs.packs | ForEach-Object {
    [ordered]@{ slug = $_.slug; name = $_.name; version = $_.version; author = $_.author
      source_url = $_.source_url; archive = $_.archive; sha256 = $_.sha256
      license = $packs.license.id; selected = [bool]$_.models_root }
  })
  assets = $final
} | ConvertTo-Json -Depth 6 | ForEach-Object { Write-Utf8 (Join-Path $targetRoot "manifest.json") $_ }

Write-Host "Imported $($final.Count) assets into $targetRoot"

