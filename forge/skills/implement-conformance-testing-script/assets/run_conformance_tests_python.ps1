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

# Try to find Python interpreter (python3 first, then python)
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $PYTHON_CMD = "python3"
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $PYTHON_CMD = "python"
} else {
    Write-Host "Error: Python interpreter not found. Please install Python."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

$current_dir = Get-Location

# Resolve conformance tests folder to an absolute path so it can be used
# from the build subfolder (where we'll Push-Location to next).
if (-not [System.IO.Path]::IsPathRooted($ConformanceTestsFolder)) {
    $ConformanceTestsFolder = Join-Path $current_dir $ConformanceTestsFolder
}

# Working folder lives in the system temp directory. $BuildFolder may be an
# absolute path, so only its leaf name is used to build the working folder name.
$PYTHON_BUILD_SUBFOLDER = Join-Path ([System.IO.Path]::GetTempPath()) "python_$(Split-Path $BuildFolder -Leaf)"

if ($env:VERBOSE -eq "1") {
    Write-Host "Preparing Python build subfolder: $PYTHON_BUILD_SUBFOLDER"
}

# Check if the Python build subfolder exists
if (Test-Path $PYTHON_BUILD_SUBFOLDER) {
    # Delete all files and folders inside
    Get-ChildItem -Path $PYTHON_BUILD_SUBFOLDER -Force | Remove-Item -Recurse -Force

    if ($env:VERBOSE -eq "1") {
        Write-Host "Cleanup completed."
    }
} else {
    if ($env:VERBOSE -eq "1") {
        Write-Host "Subfolder does not exist. Creating it..."
    }

    New-Item -ItemType Directory -Path $PYTHON_BUILD_SUBFOLDER -Force | Out-Null
}

Copy-Item -Path "$BuildFolder/*" -Destination $PYTHON_BUILD_SUBFOLDER -Recurse -Force

# Move to the subfolder
if (-not (Test-Path $PYTHON_BUILD_SUBFOLDER)) {
    Write-Host "Error: Python build folder '$PYTHON_BUILD_SUBFOLDER' does not exist."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

Push-Location $PYTHON_BUILD_SUBFOLDER

try {
    # Execute all Python conformance tests in the build folder
    Write-Host "Running Python conformance tests...`n"

    # Temporarily allow stderr output without throwing (Python unittest writes progress to stderr)
    # ForEach-Object converts ErrorRecord objects (from stderr) to plain strings to avoid verbose error formatting
    $ErrorActionPreference = 'Continue'
    $output = & $PYTHON_CMD -m unittest discover -b -s $ConformanceTestsFolder 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } | Out-String
    $exit_code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    # Echo the original output
    Write-Host $output

    # Check if no tests were discovered
    if ($output -match "Ran 0 tests in") {
        Write-Host "`nError: No unittests discovered."
        exit 1
    }

    # Exit with the exit code of the unittest command
    exit $exit_code
} finally {
    Pop-Location
    if (Test-Path $PYTHON_BUILD_SUBFOLDER) {
        Remove-Item -Path $PYTHON_BUILD_SUBFOLDER -Recurse -Force -ErrorAction SilentlyContinue
    }
}
