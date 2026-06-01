param(
    [Parameter(Position = 0)]
    [ValidateSet("find", "install", "license", "all")]
    [string]$Command = "find",

    [string]$KeyPath,
    [string]$KeyUrl,
    [string]$WinRarPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-IsAdmin)) {
        throw "This command must be run from an elevated PowerShell session."
    }
}

function Test-WinRarDirectory {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        return $false
    }

    $dir = $resolved.ProviderPath
    return (Test-Path -LiteralPath (Join-Path $dir "WinRAR.exe")) -or
        (Test-Path -LiteralPath (Join-Path $dir "Rar.exe"))
}

function Get-WinRarDirectory {
    param([string]$PreferredPath)

    $candidates = [System.Collections.Generic.List[string]]::new()

    if ($PreferredPath) {
        $candidates.Add($PreferredPath)
    }

    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) {
            $candidates.Add((Join-Path $base "WinRAR"))
        }
    }

    foreach ($registryPath in @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe"
    )) {
        $item = Get-Item -Path $registryPath -ErrorAction SilentlyContinue
        if ($item) {
            $exePath = $item.GetValue("")
            if ($exePath -and (Test-Path -LiteralPath $exePath)) {
                $candidates.Add((Split-Path -Parent $exePath))
            }
        }
    }

    $commandPath = Get-Command "WinRAR.exe" -ErrorAction SilentlyContinue
    if ($commandPath) {
        $candidates.Add((Split-Path -Parent $commandPath.Source))
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-WinRarDirectory $candidate) {
            return (Resolve-Path -LiteralPath $candidate).ProviderPath
        }
    }

    return $null
}

function Install-WinRar {
    Assert-Admin

    $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget.exe was not found. Install App Installer from Microsoft Store or install WinRAR manually."
    }

    $args = @(
        "install",
        "--id", "RARLab.WinRAR",
        "--exact",
        "--source", "winget",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )

    if ($Force) {
        $args += "--force"
    }

    & $winget.Source @args
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed with exit code $LASTEXITCODE."
    }
}

function Get-KeySourcePath {
    if ($KeyPath -and $KeyUrl) {
        throw "Use either -KeyPath or -KeyUrl, not both."
    }

    if ($KeyPath) {
        $uri = $null
        if ([Uri]::TryCreate($KeyPath, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in @("https", "http")) {
            if ($uri.Scheme -ne "https") {
                throw "Only https key URLs are supported."
            }

            $tempPath = Join-Path ([IO.Path]::GetTempPath()) ("rarreg-{0}.key" -f ([Guid]::NewGuid()))
            Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $tempPath
            return $tempPath
        }

        if (-not (Test-Path -LiteralPath $KeyPath)) {
            throw "Key file not found: $KeyPath"
        }
        return (Resolve-Path -LiteralPath $KeyPath).ProviderPath
    }

    if ($KeyUrl) {
        $uri = [Uri]$KeyUrl
        if ($uri.Scheme -ne "https") {
            throw "Only https key URLs are supported."
        }

        $tempPath = Join-Path ([IO.Path]::GetTempPath()) ("rarreg-{0}.key" -f ([Guid]::NewGuid()))
        Invoke-WebRequest -Uri $uri.AbsoluteUri -OutFile $tempPath
        return $tempPath
    }

    throw "Provide a legitimate WinRAR license with -KeyPath or -KeyUrl."
}

function Test-RarRegKey {
    param([string]$Path)

    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1
    return $firstLine -eq "RAR registration data"
}

function Install-RarRegKey {
    Assert-Admin

    $winRarDir = Get-WinRarDirectory -PreferredPath $WinRarPath
    if (-not $winRarDir) {
        throw "WinRAR was not found. Run '.\free-rar.ps1 install' first or pass -WinRarPath."
    }

    $sourcePath = Get-KeySourcePath
    if (-not (Test-RarRegKey $sourcePath)) {
        throw "The provided file does not look like a WinRAR rarreg.key file."
    }

    $destination = Join-Path $winRarDir "rarreg.key"
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        throw "rarreg.key already exists at $destination. Use -Force to overwrite it."
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destination -Force:$Force
    Write-Host "Installed license file to $destination"
}

switch ($Command) {
    "find" {
        $winRarDir = Get-WinRarDirectory -PreferredPath $WinRarPath
        if ($winRarDir) {
            Write-Host $winRarDir
        } else {
            Write-Host "WinRAR was not found."
            exit 1
        }
    }
    "install" {
        Install-WinRar
    }
    "license" {
        Install-RarRegKey
    }
    "all" {
        Install-WinRar
        Install-RarRegKey
    }
}
