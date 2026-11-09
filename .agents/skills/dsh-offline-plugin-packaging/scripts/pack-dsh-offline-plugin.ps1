[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [string]$PackageRoot,

    [string]$OutputDirectory,

    [string]$Profile,

    [switch]$Install
)

$ErrorActionPreference = 'Stop'

function Read-Manifest([string]$Directory) {
    $path = Join-Path $Directory 'package.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing package.json: $Directory"
    }
    Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
}

function Get-BundlePatches($Manifest) {
    $value = $Manifest.dsh.bundle.patch
    if ($null -eq $value) {
        throw 'package.json does not declare dsh.bundle.patch'
    }
    $patches = @($value) | Where-Object { $_ -is [string] -and $_.Length -gt 0 }
    if ($patches.Count -eq 0) {
        throw 'dsh.bundle.patch must contain at least one path'
    }
    $patches
}

function Add-ExportPaths($Value, [System.Collections.Generic.List[string]]$Paths) {
    if ($Value -is [string]) {
        if ($Value.StartsWith('./')) {
            $Paths.Add($Value)
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            Add-ExportPaths $item $Paths
        }
        return
    }
    if ($null -ne $Value) {
        foreach ($property in $Value.PSObject.Properties) {
            Add-ExportPaths $property.Value $Paths
        }
    }
}

function Get-EntryPaths($Manifest) {
    $paths = [System.Collections.Generic.List[string]]::new()
    if ($Manifest.main -is [string]) {
        $paths.Add($Manifest.main)
    }
    if ($null -ne $Manifest.exports) {
        Add-ExportPaths $Manifest.exports $paths
    }
    $paths | Where-Object { $_.StartsWith('./') } | Select-Object -Unique
}

function Get-DependencyNames($Manifest, [string]$PropertyName) {
    $property = $Manifest.PSObject.Properties[$PropertyName]
    if ($null -eq $property -or $null -eq $property.Value) {
        return @()
    }
    @($property.Value.PSObject.Properties.Name)
}

function Find-DependencyDirectory(
    [string]$Name,
    [string[]]$Roots
) {
    foreach ($root in $Roots) {
        if ([string]::IsNullOrWhiteSpace($root)) {
            continue
        }
        $candidate = Join-Path $root $Name
        if (Test-Path -LiteralPath (Join-Path $candidate 'package.json') -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    $null
}

function Copy-RuntimeDependency(
    [string]$Name,
    [string[]]$LookupRoots,
    [string]$StagingNodeModules,
    [System.Collections.Generic.HashSet[string]]$Visited,
    [System.Collections.Generic.List[string]]$Bundled,
    [System.Collections.Generic.Dictionary[string, string]]$ResolvedSources
) {
    $source = Find-DependencyDirectory $Name $LookupRoots
    if ($null -eq $source) {
        throw "Runtime dependency is unavailable: $Name"
    }
    if ($Visited.Contains($Name)) {
        if ($ResolvedSources[$Name] -ne $source) {
            $first = Read-Manifest $ResolvedSources[$Name]
            $next = Read-Manifest $source
            if ([string]$first.version -ne [string]$next.version) {
                throw "Conflicting runtime dependency versions for '${Name}' from '$($ResolvedSources[$Name])' and '$source': $($first.version) and $($next.version)"
            }
        }
        return
    }
    $ResolvedSources[$Name] = $source
    $Visited.Add($Name) | Out-Null

    $destination = Join-Path $StagingNodeModules $Name
    $parent = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force
    $Bundled.Add($Name)

}

function Get-PackageRoot([string]$Root) {
    if (Test-Path -LiteralPath (Join-Path $Root 'package.json') -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Root).Path
    }
    $candidates = @(
        Get-ChildItem -LiteralPath $Root -Filter package.json -File -Recurse -ErrorAction SilentlyContinue |
            ForEach-Object {
                try {
                    $manifest = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
                    if ($null -ne $manifest.dsh.bundle.patch) {
                        $_.Directory.FullName
                    }
                } catch {
                    # Ignore non-package JSON files while discovering a candidate.
                }
            }
    ) | Select-Object -Unique
    if ($candidates.Count -ne 1) {
        $listed = if ($candidates.Count -eq 0) { '<none>' } else { $candidates -join [Environment]::NewLine }
        throw "Expected exactly one DSH bundle package; found $($candidates.Count):$([Environment]::NewLine)$listed. Pass -PackageRoot explicitly."
    }
    $candidates[0]
}

function Test-DshHarness {
    if (Get-Command dsh -ErrorAction SilentlyContinue) {
        return $true
    }
    $manifestPath = Join-Path (Get-Location) 'package.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        return $false
    }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $manifest.name -eq '@deepseek-ai/dsh-root' -and $null -ne $manifest.scripts.dsh
}

$source = (Resolve-Path -LiteralPath $SourceRoot).Path
$package = if ($PackageRoot) { (Resolve-Path -LiteralPath $PackageRoot).Path } else { Get-PackageRoot $source }
$manifest = Read-Manifest $package
$patches = Get-BundlePatches $manifest
$entries = Get-EntryPaths $manifest
if ($entries.Count -eq 0) {
    throw 'package.json does not declare main or a runtime exports entry'
}

foreach ($patch in $patches) {
    if (-not (Test-Path -LiteralPath (Join-Path $package $patch) -PathType Leaf)) {
        throw "Bundle patch is missing: $patch"
    }
}
foreach ($entry in $entries) {
    if (-not $entry.StartsWith('./')) {
        throw "Runtime entry is not a local package path: $entry"
    }
    $relativeEntry = $entry.Substring(2)
    if ($relativeEntry.Contains('*')) {
        $matches = @(Get-ChildItem -Path (Join-Path $package $relativeEntry) -File -ErrorAction SilentlyContinue)
        if ($matches.Count -eq 0) {
            throw "Built runtime entry glob matches no files: $entry"
        }
    } elseif (-not (Test-Path -LiteralPath (Join-Path $package $relativeEntry) -PathType Leaf)) {
        throw "Built runtime entry is missing: $entry"
    }
}

$name = [string]$manifest.name
$version = [string]$manifest.version
if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($version)) {
    throw 'package.json must declare name and version'
}
$safeName = $name.TrimStart('@').Replace('/', '-')
$output = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $source 'offline-transfer' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$output = (Resolve-Path -LiteralPath $output).Path
$staging = Join-Path $output ('.staging-' + [Guid]::NewGuid().ToString('N'))
$stagingNodeModules = Join-Path $staging 'node_modules'
New-Item -ItemType Directory -Force -Path $staging,$stagingNodeModules | Out-Null

try {
    Get-ChildItem -LiteralPath $package -Force |
        Where-Object { $_.Name -ne 'node_modules' } |
        Copy-Item -Destination $staging -Recurse -Force

    $lookupRoots = @(
        (Join-Path $package 'node_modules'),
        (Split-Path -Parent $package),
        (Join-Path $source 'node_modules')
    ) | Select-Object -Unique
    $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $bundled = [System.Collections.Generic.List[string]]::new()
    $resolvedSources = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::OrdinalIgnoreCase)
    $optional = Get-DependencyNames $manifest 'optionalDependencies'
    $required = Get-DependencyNames $manifest 'dependencies'
    foreach ($dependency in $required) {
        Copy-RuntimeDependency $dependency $lookupRoots $stagingNodeModules $visited $bundled $resolvedSources
    }
    foreach ($dependency in $optional) {
        if ($required -contains $dependency) { continue }
        try {
            Copy-RuntimeDependency $dependency $lookupRoots $stagingNodeModules $visited $bundled $resolvedSources
        } catch {
            Write-Warning "Optional runtime dependency is unavailable and will not be bundled: $dependency"
        }
    }

    $stagedManifestPath = Join-Path $staging 'package.json'
    $stagedManifest = Read-Manifest $staging
    $existingBundled = @($stagedManifest.bundledDependencies)
    $stagedManifest | Add-Member -NotePropertyName bundledDependencies -NotePropertyValue @($existingBundled + $bundled | Select-Object -Unique) -Force
    $json = $stagedManifest | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($stagedManifestPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

    Push-Location $staging
    try {
        & npm pack --ignore-scripts --pack-destination $output --json | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "npm pack failed with exit code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }

    $tarball = Join-Path $output "$safeName-$version.tgz"
    if (-not (Test-Path -LiteralPath $tarball -PathType Leaf)) {
        throw "npm pack did not produce the expected tarball: $tarball"
    }
    $entriesInTarball = @(tar -tzf $tarball)
    foreach ($patch in $patches) {
        $normalizedPatch = $patch.Replace('\', '/')
        $entry = 'package/' + $normalizedPatch.TrimStart('./')
        if ($entriesInTarball -notcontains $entry) {
            throw "Tarball is missing bundle patch: $entry"
        }
    }
    foreach ($entry in $entries) {
        $tarEntry = 'package/' + $entry.Substring(2).Replace('\', '/')
        if ($tarEntry.Contains('*')) {
            $prefix = $tarEntry.Split('*')[0]
            if (-not ($entriesInTarball | Where-Object { $_.StartsWith($prefix) })) {
                throw "Tarball is missing runtime entry glob: $tarEntry"
            }
        } elseif ($entriesInTarball -notcontains $tarEntry) {
            throw "Tarball is missing runtime entry: $tarEntry"
        }
    }
    foreach ($dependency in @($bundled | Select-Object -Unique)) {
        $dependencyEntry = 'package/node_modules/' + $dependency.Replace('\', '/') + '/package.json'
        if ($entriesInTarball -notcontains $dependencyEntry) {
            throw "Tarball is missing bundled dependency: $dependencyEntry"
        }
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $tarball).Hash
    Write-Output "Tarball: $tarball"
    Write-Output "SHA256: $hash"
    Write-Output "Bundled dependencies: $(@($bundled | Select-Object -Unique) -join ', ')"

    $dsh = Test-DshHarness
    if ($dsh -and $Profile) {
        $command = "pnpm dsh plugin --profile $Profile add `"$tarball`" --offline"
        Write-Output "DSH install command: $command"
        if ($Install) {
            & pnpm dsh plugin --profile $Profile add $tarball --offline
            if ($LASTEXITCODE -ne 0) {
                throw "DSH plugin installation failed with exit code $LASTEXITCODE"
            }
        }
    } elseif ($Install) {
        throw 'Direct installation requested, but the current working directory is not a detectable DSH Agent Harness or no -Profile was supplied.'
    }
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
