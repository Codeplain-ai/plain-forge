#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

$UNRECOVERABLE_ERROR_EXIT_CODE = 69

# ANSI escape code pattern to remove color codes and formatting from output
$ANSI_ESCAPE_PATTERN = '\x1b\[[0-9;]*[mK]'

# Check if subfolder name is provided
if (-not $args[0]) {
    Write-Host "Error: No subfolder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <subfolder_name>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

$BuildFolder = $args[0]

# Define the path to the subfolder
$NODE_SUBFOLDER = "node_$BuildFolder"

if ($env:VERBOSE -eq "1") {
    Write-Host "Preparing Node subfolder: $NODE_SUBFOLDER"
}

# Check if the node subfolder exists
if (Test-Path $NODE_SUBFOLDER) {
    # Delete all files and folders except "node_modules", "build", and "package-lock.json"
    Get-ChildItem -Path $NODE_SUBFOLDER -Force |
        Where-Object {
            $_.Name -ne "node_modules" -and
            $_.Name -ne "build" -and
            $_.Name -ne "package-lock.json"
        } | Remove-Item -Recurse -Force

    if ($env:VERBOSE -eq "1") {
        Write-Host "Cleanup completed, keeping 'node_modules' and 'package-lock.json'."
    }
} else {
    if ($env:VERBOSE -eq "1") {
        Write-Host "Subfolder does not exist. Creating it..."
    }

    New-Item -ItemType Directory -Path $NODE_SUBFOLDER -Force | Out-Null
}

Copy-Item -Path "$BuildFolder/*" -Destination $NODE_SUBFOLDER -Recurse -Force

# Move to the subfolder
if (-not (Test-Path $NODE_SUBFOLDER)) {
    Write-Host "Error: Subfolder '$BuildFolder' does not exist."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

Push-Location $NODE_SUBFOLDER

try {
    # Install libraries
    npm install

    # Execute all React unittests in the subfolder
    Write-Host "Running React unittests in $BuildFolder..."
    # Temporarily allow stderr output without throwing (npm/jest may write to stderr)
    # ForEach-Object converts ErrorRecord objects (from stderr) to plain strings to avoid verbose error formatting
    $ErrorActionPreference = 'Continue'
    $output = npm test -- --runInBand --silent --detectOpenHandles 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } | Out-String
    $TEST_EXIT_CODE = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    # Strip ANSI escape codes
    $output = $output -replace $ANSI_ESCAPE_PATTERN, ''
    Write-Host $output

    # Check if tests failed
    if ($TEST_EXIT_CODE -ne 0) {
        Write-Host "Error: Tests failed with exit code $TEST_EXIT_CODE"
        exit $TEST_EXIT_CODE
    }

    exit $TEST_EXIT_CODE
} finally {
    Pop-Location
}
