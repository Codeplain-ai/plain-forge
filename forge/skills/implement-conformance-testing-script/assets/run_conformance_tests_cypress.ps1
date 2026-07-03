#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

$UNRECOVERABLE_ERROR_EXIT_CODE = 69

$NPM_INSTALL_OUTPUT_FILTER = "up to date in|added [0-9]* packages, removed [0-9]* packages, and changed [0-9]* packages in|removed [0-9]* packages, and changed [0-9]* packages in|added [0-9]* packages in|removed [0-9]* packages in"

# Function to check and kill any Node process running on port 3000 (React development server)
function Check-AndKillNodeServer {
    try {
        $connections = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue
        if ($connections) {
            foreach ($conn in $connections) {
                $proc = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                if ($proc -and $proc.ProcessName -eq "node") {
                    Write-Host "Found Node server running on port 3000. Killing it..."
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 1
                    if ($env:VERBOSE -eq "1") {
                        Write-Host "Node server terminated."
                    }
                }
            }
        }
    } catch {
        # Silently ignore errors (port may not be in use)
    }
}

# Function to get all child processes of a given PID recursively
function Get-ChildProcesses {
    param([int]$ParentPid)

    $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ParentPid" -ErrorAction SilentlyContinue
    $result = @()
    foreach ($child in $children) {
        $result += $child.ProcessId
        $result += Get-ChildProcesses -ParentPid $child.ProcessId
    }
    return $result
}

# Cleanup function to ensure all processes are terminated
function Cleanup {
    # Kill any running npm processes started by this script
    if ($script:NPM_PID) {
        Stop-Process -Id $script:NPM_PID -Force -ErrorAction SilentlyContinue
    }

    # Kill React app and its children if they exist
    if ($script:REACT_APP_PID) {
        $processesToKill = Get-ChildProcesses -ParentPid $script:REACT_APP_PID

        # Kill the main process
        Stop-Process -Id $script:REACT_APP_PID -Force -ErrorAction SilentlyContinue

        # Kill all the subprocesses
        foreach ($pid in $processesToKill) {
            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        }

        if ($env:VERBOSE -eq "1") {
            Write-Host "React app is terminated!"
        }
    }

    # Remove temporary files if they exist
    if ($script:build_output -and (Test-Path $script:build_output)) {
        Remove-Item $script:build_output -Force -ErrorAction SilentlyContinue
    }

    # Step out of any temp subfolder we may still be in before deleting it
    Set-Location -Path ([System.IO.Path]::GetTempPath()) -ErrorAction SilentlyContinue

    # Remove temporary build subfolders if they exist
    if ($script:NODE_SUBFOLDER -and (Test-Path $script:NODE_SUBFOLDER)) {
        Remove-Item -Path $script:NODE_SUBFOLDER -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($script:NODE_CONFORMANCE_TESTS_SUBFOLDER -and (Test-Path $script:NODE_CONFORMANCE_TESTS_SUBFOLDER)) {
        Remove-Item -Path $script:NODE_CONFORMANCE_TESTS_SUBFOLDER -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check for and kill any existing Node server from previous runs
Check-AndKillNodeServer

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

if ($args[2] -eq "-v" -or $args[2] -eq "--verbose") {
    $env:VERBOSE = "1"
}

$current_dir = Get-Location

try {
    # Define the path to the subfolder. It lives in the system temp directory;
    # $BuildFolder may be an absolute path, so only its leaf name is used.
    $script:NODE_SUBFOLDER = Join-Path ([System.IO.Path]::GetTempPath()) "node_$(Split-Path $BuildFolder -Leaf)"

    # Running React application
    Write-Host "### Step 1: Starting the React application in folder $script:NODE_SUBFOLDER..."

    if ($env:VERBOSE -eq "1") {
        Write-Host "Preparing Node subfolder: $script:NODE_SUBFOLDER"
    }

    # Check if the node subfolder exists
    if (Test-Path $script:NODE_SUBFOLDER) {
        # Delete all files and folders except "node_modules", "plain_modules", and "package-lock.json"
        Get-ChildItem -Path $script:NODE_SUBFOLDER -Force |
            Where-Object {
                $_.Name -ne "node_modules" -and
                $_.Name -ne "plain_modules" -and
                $_.Name -ne "package-lock.json"
            } | Remove-Item -Recurse -Force

        if ($env:VERBOSE -eq "1") {
            Write-Host "Cleanup completed, keeping 'node_modules' and 'package-lock.json'."
        }
    } else {
        if ($env:VERBOSE -eq "1") {
            Write-Host "Subfolder does not exist. Creating it..."
        }

        New-Item -ItemType Directory -Path $script:NODE_SUBFOLDER -Force | Out-Null
    }

    Copy-Item -Path "$BuildFolder/*" -Destination $script:NODE_SUBFOLDER -Recurse -Force

    # Move to the subfolder
    if (-not (Test-Path $script:NODE_SUBFOLDER)) {
        Write-Host "Error: Node build folder '$script:NODE_SUBFOLDER' does not exist."
        exit $UNRECOVERABLE_ERROR_EXIT_CODE
    }

    Push-Location $script:NODE_SUBFOLDER

    # Temporarily allow stderr output without throwing (npm may write warnings to stderr)
    # ForEach-Object converts ErrorRecord objects (from stderr) to plain strings to avoid verbose error formatting
    $ErrorActionPreference = 'Continue'
    $npmInstallOutput = npm install --prefer-offline --no-audit --no-fund --loglevel error 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } | Out-String
    $ErrorActionPreference = 'Stop'
    # Filter out noisy npm install lines
    $npmInstallOutput -split "`n" | Where-Object { $_ -notmatch $NPM_INSTALL_OUTPUT_FILTER } | ForEach-Object {
        if ($_.Trim()) { Write-Host $_ }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Installing Node modules."
        exit 2
    }

    if ($env:VERBOSE -eq "1") {
        Write-Host "Building the application..."
    }

    $script:build_output = [System.IO.Path]::GetTempFileName()

    # Temporarily allow stderr output without throwing (build tools may write to stderr)
    $ErrorActionPreference = 'Continue'
    npm run build > $script:build_output 2>&1
    $ErrorActionPreference = 'Stop'

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Building application."
        Get-Content $script:build_output
        Remove-Item $script:build_output -Force -ErrorAction SilentlyContinue
        exit 2
    }

    Remove-Item $script:build_output -Force -ErrorAction SilentlyContinue

    if ($env:VERBOSE -eq "1") {
        Write-Host "Starting the application..."
    }

    # Start the React app in the background and redirect output to a log file
    $env:BROWSER = "none"
    $reactProcess = Start-Process -FilePath "npm" -ArgumentList "start", "--", "--no-open" `
        -NoNewWindow -PassThru -RedirectStandardOutput "app.log" -RedirectStandardError "app_err.log"

    if ($env:VERBOSE -eq "1") {
        Write-Host "Application is starting..."
    }

    # Capture the process ID
    $script:REACT_APP_PID = $reactProcess.Id

    # Try to find the child npm process
    Start-Sleep -Milliseconds 500
    $npmChild = Get-CimInstance Win32_Process -Filter "ParentProcessId = $($script:REACT_APP_PID)" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "npm" } | Select-Object -First 1
    if ($npmChild) {
        $script:NPM_PID = $npmChild.ProcessId
    }

    # Wait for the "compiled successfully!" or Vite ready message in the log file
    while ($true) {
        if (Test-Path "app.log") {
            $logContent = Get-Content "app.log" -Raw -ErrorAction SilentlyContinue
            if ($logContent) {
                if ($logContent -match "(?i)compiled successfully|compiled with warnings") {
                    break
                }
                if ($logContent -match "(?i)VITE v[0-9]+\.[0-9]+\.[0-9]+\s+ready in") {
                    break
                }
            }
        }

        # Also check if localhost:3000 responds
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($response) { break }
        } catch {
            # Not ready yet
        }

        # Check if the React app process is still running
        $proc = Get-Process -Id $script:REACT_APP_PID -ErrorAction SilentlyContinue
        if (-not $proc -or $proc.HasExited) {
            Write-Host "Error in :ImplementationCode: (React app process (PID: $($script:REACT_APP_PID)) has terminated unexpectedly)."
            if (Test-Path "app.log") { Get-Content "app.log" }
            if (Test-Path "app_err.log") { Get-Content "app_err.log" }
            exit 2
        }

        Start-Sleep -Milliseconds 100
    }

    # At this point, the React app is up and running in the background
    if ($env:VERBOSE -eq "1") {
        Write-Host "React app is up and running!"
    }

    Pop-Location

    # Execute all Cypress conformance tests in the build folder
    Write-Host "### Step 2: Running Cypress conformance tests $ConformanceTestsFolder..."

    # Move back to the original directory
    Set-Location $current_dir

    # Define the path to the conformance tests subfolder. It lives in the system
    # temp directory; $ConformanceTestsFolder may be absolute, so only its leaf name is used.
    $script:NODE_CONFORMANCE_TESTS_SUBFOLDER = Join-Path ([System.IO.Path]::GetTempPath()) "node_$(Split-Path $ConformanceTestsFolder -Leaf)"

    if ($env:VERBOSE -eq "1") {
        Write-Host "Preparing conformance tests Node subfolder: $script:NODE_CONFORMANCE_TESTS_SUBFOLDER"
    }

    # Check if the conformance tests node subfolder exists
    if (Test-Path $script:NODE_CONFORMANCE_TESTS_SUBFOLDER) {
        # Delete all files and folders except "node_modules", "plain_modules", and "package-lock.json"
        Get-ChildItem -Path $script:NODE_CONFORMANCE_TESTS_SUBFOLDER -Force |
            Where-Object {
                $_.Name -ne "node_modules" -and
                $_.Name -ne "plain_modules" -and
                $_.Name -ne "package-lock.json"
            } | Remove-Item -Recurse -Force

        if ($env:VERBOSE -eq "1") {
            Write-Host "Cleanup completed, keeping 'node_modules' and 'package-lock.json'."
        }
    } else {
        if ($env:VERBOSE -eq "1") {
            Write-Host "Subfolder does not exist. Creating it..."
        }

        New-Item -ItemType Directory -Path $script:NODE_CONFORMANCE_TESTS_SUBFOLDER -Force | Out-Null
    }

    Copy-Item -Path "$ConformanceTestsFolder/*" -Destination $script:NODE_CONFORMANCE_TESTS_SUBFOLDER -Recurse -Force

    # Move to the subfolder with Cypress tests
    if (-not (Test-Path $script:NODE_CONFORMANCE_TESTS_SUBFOLDER)) {
        Write-Host "Error: conformance tests Node folder '$script:NODE_CONFORMANCE_TESTS_SUBFOLDER' does not exist."
        exit $UNRECOVERABLE_ERROR_EXIT_CODE
    }

    Push-Location $script:NODE_CONFORMANCE_TESTS_SUBFOLDER

    # Temporarily allow stderr output without throwing (npm may write warnings to stderr)
    # ForEach-Object converts ErrorRecord objects (from stderr) to plain strings to avoid verbose error formatting
    $ErrorActionPreference = 'Continue'
    $npmInstallOutput = npm install cypress --save-dev --prefer-offline --no-audit --no-fund --loglevel error 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } | Out-String
    $ErrorActionPreference = 'Stop'
    $npmInstallOutput -split "`n" | Where-Object { $_ -notmatch $NPM_INSTALL_OUTPUT_FILTER } | ForEach-Object {
        if ($_.Trim()) { Write-Host $_ }
    }

    if ($env:VERBOSE -eq "1") {
        Write-Host "Running Cypress conformance tests..."
    }

    $ErrorActionPreference = 'Continue'
    $cypress_info_output = npx cypress info 2>&1 | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } } | Out-String
    $ErrorActionPreference = 'Stop'
    $CYPRESS_BROWSER_FLAG = ""
    if ($cypress_info_output -match "(?i)chrome") {
        $CYPRESS_BROWSER_FLAG = "--browser=chrome"
    }
    Write-Host "CYPRESS_BROWSER_FLAG: $(if ($CYPRESS_BROWSER_FLAG) { $CYPRESS_BROWSER_FLAG } else { 'none' })"

    $env:BROWSERSLIST_IGNORE_OLD_DATA = "1"
    if ($CYPRESS_BROWSER_FLAG) {
        npx cypress run $CYPRESS_BROWSER_FLAG --config video=false 2>$null
    } else {
        npx cypress run --config video=false 2>$null
    }
    $cypress_run_result = $LASTEXITCODE

    if ($cypress_run_result -ne 0) {
        if ($env:VERBOSE -eq "1") {
            Write-Host "Error: Cypress conformance tests have failed."
        }
        exit 1
    }
} finally {
    Cleanup
}
