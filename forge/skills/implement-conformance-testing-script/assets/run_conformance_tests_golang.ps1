#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

$UNRECOVERABLE_ERROR_EXIT_CODE = 69

# Check if build folder name is provided
if (-not $args[0]) {
    Write-Host "Error: No build folder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <build_folder_name> <conformance_tests_folder>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

# Check if conformance tests folder name is provided
if (-not $args[1]) {
    Write-Host "Error: No conformance tests folder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <build_folder_name> <conformance_tests_folder>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

$BuildFolder = $args[0]
$ConformanceTestsFolder = $args[1]

$current_dir = Get-Location

# Resolve conformance tests folder to an absolute path so it can be used
# from the build subfolder (where we'll Push-Location to next).
if (-not [System.IO.Path]::IsPathRooted($ConformanceTestsFolder)) {
    $ConformanceTestsFolder = Join-Path $current_dir $ConformanceTestsFolder
}

# Working folder lives in the system temp directory. $BuildFolder may be an
# absolute path, so only its leaf name is used to build the working folder name.
$GO_BUILD_SUBFOLDER = Join-Path ([System.IO.Path]::GetTempPath()) "go_$(Split-Path $BuildFolder -Leaf)"

if ($env:VERBOSE -eq "1") {
    Write-Host "Preparing Go build subfolder: $GO_BUILD_SUBFOLDER"
}

# Check if the go build subfolder exists
if (Test-Path $GO_BUILD_SUBFOLDER) {
    # Delete all files and folders inside
    Get-ChildItem -Path $GO_BUILD_SUBFOLDER -Force | Remove-Item -Recurse -Force

    if ($env:VERBOSE -eq "1") {
        Write-Host "Cleanup completed."
    }
} else {
    if ($env:VERBOSE -eq "1") {
        Write-Host "Subfolder does not exist. Creating it..."
    }

    New-Item -ItemType Directory -Path $GO_BUILD_SUBFOLDER -Force | Out-Null
}

Copy-Item -Path "$BuildFolder/*" -Destination $GO_BUILD_SUBFOLDER -Recurse -Force

# Move to the subfolder
if (-not (Test-Path $GO_BUILD_SUBFOLDER)) {
    Write-Host "Error: Go build folder '$GO_BUILD_SUBFOLDER' does not exist."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

Push-Location $GO_BUILD_SUBFOLDER

try {
    Write-Host "Runinng go get in the build folder..."
    go get

    # Move to conformance tests folder
    Set-Location $ConformanceTestsFolder
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        Write-Host "Error: Conformance tests folder '$ConformanceTestsFolder' does not exist."
        exit $UNRECOVERABLE_ERROR_EXIT_CODE
    }

    Write-Host "Checking for go.mod in conformance test directory..."
    if (Test-Path "go.mod") {
        Write-Host "Running go get in conformance test directory..."
        go get
    } else {
        Write-Host "No go.mod found in conformance test directory, skipping go get"
    }

    # Move back to build directory
    Set-Location $GO_BUILD_SUBFOLDER

    # Execute Go lang conformance tests
    Write-Host "Running Golang conformance tests...`n"

    # Temporarily allow stderr output without throwing (Go may write to stderr)
    # ForEach-Object converts ErrorRecord objects (from stderr) to plain strings to avoid verbose error formatting
    $ErrorActionPreference = 'Continue'
    $output = go run (Join-Path $ConformanceTestsFolder "conformance_tests.go") 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } | Out-String
    $exit_code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    # If there was an error, print the output and exit with the error code
    if ($exit_code -ne 0) {
        Write-Host $output
        exit $exit_code
    }

    # Exit with the exit code of the test command
    exit $exit_code
} finally {
    Pop-Location
    if (Test-Path $GO_BUILD_SUBFOLDER) {
        Remove-Item -Path $GO_BUILD_SUBFOLDER -Recurse -Force -ErrorAction SilentlyContinue
    }
}
