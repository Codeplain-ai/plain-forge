#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

$UNRECOVERABLE_ERROR_EXIT_CODE = 69

if (-not $args[0]) {
    Write-Host "Error: No source folder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <source_folder_name>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Error: flutter is not available in PATH."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

$SOURCE_FOLDER = $args[0]
# Working folder lives in the system temp directory. $SOURCE_FOLDER may be an
# absolute path, so only its leaf name is used to build the working folder name.
$BUILD_SUBFOLDER = Join-Path ([System.IO.Path]::GetTempPath()) "flutter_$(Split-Path $SOURCE_FOLDER -Leaf)"

Write-Host "Current directory: $(Get-Location)"
Write-Host "Source folder: $SOURCE_FOLDER"
Write-Host "--------------------------------"

if (Test-Path $BUILD_SUBFOLDER) {
    Remove-Item -Path $BUILD_SUBFOLDER -Recurse -Force
}
New-Item -ItemType Directory -Path $BUILD_SUBFOLDER -Force | Out-Null

Copy-Item -Path "$SOURCE_FOLDER/*" -Destination "$BUILD_SUBFOLDER/" -Recurse -Force

if (-not (Test-Path $BUILD_SUBFOLDER)) {
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

Push-Location $BUILD_SUBFOLDER

try {
    Write-Host "Resolving Flutter dependencies..."

    if (Test-Path "pubspec.yaml") {
        flutter pub get
    } else {
        Write-Host "Warning: pubspec.yaml not found. Dependencies might be missing."
    }

    Write-Host "Running Flutter unittests in $BUILD_SUBFOLDER..."

    # Run flutter test with a timeout
    $process = Start-Process -FilePath "flutter" -ArgumentList "test", "--reporter", "expanded" `
        -NoNewWindow -PassThru -RedirectStandardOutput "flutter_test_stdout.txt" -RedirectStandardError "flutter_test_stderr.txt"

    $timedOut = $false
    if (-not $process.WaitForExit(120000)) {
        $timedOut = $true
        $process | Stop-Process -Force
    }

    $output = ""
    if (Test-Path "flutter_test_stdout.txt") {
        $output += Get-Content "flutter_test_stdout.txt" -Raw -ErrorAction SilentlyContinue
    }
    if (Test-Path "flutter_test_stderr.txt") {
        $output += Get-Content "flutter_test_stderr.txt" -Raw -ErrorAction SilentlyContinue
    }

    $exit_code = $process.ExitCode

    if ($timedOut) {
        Write-Host "`nError: Unittests timed out after 120 seconds."
        exit 124
    }

    Write-Host $output

    exit $exit_code
} finally {
    # Clean up temp files
    Remove-Item -Path "flutter_test_stdout.txt" -ErrorAction SilentlyContinue
    Remove-Item -Path "flutter_test_stderr.txt" -ErrorAction SilentlyContinue
    Pop-Location
    if (Test-Path $BUILD_SUBFOLDER) {
        Remove-Item -Path $BUILD_SUBFOLDER -Recurse -Force -ErrorAction SilentlyContinue
    }
}
