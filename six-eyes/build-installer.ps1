param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$projectFile = Join-Path $projectRoot "six-eyes.csproj"
$legacyArtifactsDir = Join-Path $projectRoot "artifacts"
$artifactsDir = Join-Path $projectRoot "bin\InstallerArtifacts"
$publishDir = Join-Path $artifactsDir "publish"
$installerDir = Join-Path $artifactsDir "installer"
$issPath = Join-Path $artifactsDir "SixEyes.generated.iss"
$buildOutputDir = Join-Path $projectRoot "bin\Debug\net8.0-windows"

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

function Find-InnoCompiler {
    $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @()
    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
    }
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw @"
Inno Setup 6 belum terpasang.
Install dengan perintah berikut, lalu jalankan script ini lagi:
winget install --id JRSoftware.InnoSetup -e
"@
}

$innoCompiler = Find-InnoCompiler

Write-Host "[1/6] Publishing self-contained .NET runtime..." -ForegroundColor Cyan
if (Test-Path $legacyArtifactsDir) {
    Remove-Item $legacyArtifactsDir -Recurse -Force
}
if (Test-Path $artifactsDir) {
    Remove-Item $artifactsDir -Recurse -Force
}
New-Item $publishDir -ItemType Directory -Force | Out-Null
New-Item $installerDir -ItemType Directory -Force | Out-Null

$publishArguments = @(
    "publish",
    $projectFile,
    "-c", "Debug",
    "-r", "win-x64",
    "--self-contained", "true",
    "-p:PublishSingleFile=false",
    "-p:PublishTrimmed=false",
    "-o", $publishDir
)
Invoke-CheckedCommand -Command "dotnet" -Arguments $publishArguments

Write-Host "[2/6] Building Qt host and deploying Qt..." -ForegroundColor Cyan
$buildArguments = @(
    "build",
    $projectFile,
    "-c", "Debug"
)
Invoke-CheckedCommand -Command "dotnet" -Arguments $buildArguments

Get-ChildItem $buildOutputDir |
    Where-Object { $_.Name -ne "win-x64" } |
    Copy-Item -Destination $publishDir -Recurse -Force

$applicationExe = Join-Path $publishDir "six-eyes.exe"
Write-Host "[3/6] Validating application files..." -ForegroundColor Cyan
$requiredFiles = @(
    $applicationExe,
    (Join-Path $publishDir "platforms\qwindows.dll")
)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path $requiredFile)) {
        throw "File publish wajib tidak ditemukan: $requiredFile"
    }
}

Write-Host "[4/6] Smoke testing application..." -ForegroundColor Cyan
$applicationProcess = Start-Process -FilePath $applicationExe -WorkingDirectory $publishDir -PassThru
Start-Sleep -Seconds 5
if ($applicationProcess.HasExited) {
    throw "Aplikasi berhenti saat smoke test dengan exit code $($applicationProcess.ExitCode)"
}
Stop-Process -Id $applicationProcess.Id

Write-Host "[5/6] Generating Inno Setup configuration..." -ForegroundColor Cyan
$issContent = @"
#define MyAppName "Six Eyes"
#define MyAppVersion "$Version"
#define MyAppPublisher "Six Eyes"
#define MyAppExeName "six-eyes.exe"

[Setup]
AppId={{9C24BF9F-A6B4-4FFB-B662-E20284CFED24}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Six Eyes
DefaultGroupName=Six Eyes
DisableProgramGroupPage=yes
OutputDir=$installerDir
OutputBaseFilename=SixEyesSetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "$publishDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Six Eyes"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\Six Eyes"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Run Six Eyes"; Flags: nowait postinstall skipifsilent
"@
Set-Content -Path $issPath -Value $issContent -Encoding UTF8

Write-Host "[6/6] Building installer..." -ForegroundColor Cyan
Invoke-CheckedCommand -Command $innoCompiler -Arguments @($issPath)

$installerPath = Join-Path $installerDir "SixEyesSetup.exe"
if (-not (Test-Path $installerPath)) {
    throw "Inno Setup selesai, tetapi installer tidak ditemukan: $installerPath"
}

Write-Host ""
Write-Host "Installer berhasil dibuat:" -ForegroundColor Green
Write-Host $installerPath -ForegroundColor Green
