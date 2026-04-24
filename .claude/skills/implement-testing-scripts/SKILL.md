---
name: implement-testing-scripts
description: >-
  Create testing and environment scripts (run_unittests, run_conformance_tests,
  prepare_environment) for a given language/technology. Scripts follow the
  established patterns in test_scripts/ and exit with code 69 for environment
  issues. Use when the user needs new testing scripts for a language.
---

# Implement Testing Scripts

## When to Use

- The user wants to add testing scripts for a new language or technology.
- The user needs run_unittests, run_conformance_tests, or prepare_environment scripts.
- The user wants scripts that follow the same conventions as the existing ones in `test_scripts/`.

## Overview

There are three types of scripts, each unique to every language/technology. All scripts are invoked by the codeplain renderer with paths relative to the workspace root:

| Script Type | Purpose | Invocation |
|---|---|---|
| **run_unittests** | Copies build output to a staging folder and runs unit tests | `run_unittests_<lang>.sh plain_modules/<module_name>` |
| **run_conformance_tests** | Copies build output + conformance tests to staging folders and runs conformance tests | `run_conformance_tests_<lang>.sh plain_modules/<module_name> conformance_tests/<module_name>/<functionality>` |
| **prepare_environment** | Copies build output into an existing project folder and runs build/install (no tests) | `prepare_environment_<lang>.sh plain_modules/<module_name>` |

Each script type is created as a `.sh` (bash) or `.ps1` (PowerShell) file depending on the user's OS.

## Phase 1 — Ask the User

Use **AskQuestion** to gather the following:

### 1a. Which scripts to create

Ask which of the three script types the user needs. Allow multiple selection:
- run_unittests
- run_conformance_tests
- prepare_environment

### 1b. Language / technology

Ask the user which language or technology the scripts are for. Examples: Python, Java, Flutter, Go, TypeScript/Node, Rust, etc.

### 1c. Detect the user's OS

Detect the user's operating system automatically from the environment (check the `OS Version` in the user info or run `uname`). Use this to decide the script format:

- **macOS / Linux** → create `.sh` (bash) scripts
- **Windows** → create `.ps1` (PowerShell) scripts

If detection is ambiguous, ask the user which format they need. Do **not** ask if the OS is clear from context.

### 1d. Language-specific details

Based on the chosen language, ask any clarifying questions needed to write the scripts. For example:
- **Java**: Which Java version? Does the project use Maven or Gradle?
- **Python**: Use `unittest discover` or `pytest`?
- **Flutter**: Which test runner? (`flutter test`?)
- **Node/TypeScript**: Which test runner? (`npm test`, `jest`, `vitest`?)
- **Go**: Standard `go test ./...`?
- **Rust**: Standard `cargo test`?

Also ask:
- Should the scripts clear any external service data before running? (e.g., `curl http://localhost:6000/api/v2/clear-data` as seen in Java examples)
- Is there a build step required before tests? (e.g., `mvn clean install -DskipTests`)

### 1e. Confirm the plan

Summarize:
- Script types to create
- Language / technology and version requirements
- Detected OS and script format (`.sh` for macOS/Linux, `.ps1` for Windows)
- File names that will be created (following naming convention: `<script_type>_<language>.sh` or `<script_type>_<language>.ps1`)
- Key behaviors (environment checks, build steps, test commands)

Get explicit confirmation before proceeding.

## Phase 2 — Implement the Scripts

Create each script in the `test_scripts/` directory. Follow the patterns below exactly.

### Naming Convention

Scripts are named: `<script_type>_<language>.<ext>`

Examples:
- `run_unittests_flutter.sh`
- `run_conformance_tests_go.sh`
- `prepare_environment_rust.ps1`

### Required Patterns (apply to ALL scripts)

Every script **must** follow these patterns, extracted from the existing examples:

#### 1. Unrecoverable error exit code

All environment / setup errors must exit with code **69**:

```bash
UNRECOVERABLE_ERROR_EXIT_CODE=69
```

```powershell
$UNRECOVERABLE_ERROR_EXIT_CODE = 69
```

#### 2. Environment check

At the top of every script, verify that the required tool is installed. If not, print a helpful error message telling the user what to install and exit with code 69.

**Bash example (Python):**
```bash
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    printf "Error: Python interpreter not found. Please install Python.\n"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
```

**Bash example (Java):**
```bash
if ! command -v java &> /dev/null; then
    printf "Error: Java not found. Please install JDK 21 (e.g., 'brew install openjdk@21' or download from https://adoptium.net).\n"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
```

**Bash example (Flutter):**
```bash
if ! command -v flutter &> /dev/null; then
    printf "Error: Flutter SDK not found. Please install Flutter (https://docs.flutter.dev/get-started/install).\n"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
```

**PowerShell example:**
```powershell
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Flutter SDK not found. Please install Flutter (https://docs.flutter.dev/get-started/install)."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}
```

Also check for build tools if required (e.g., `mvn`, `gradle`, `npm`, `cargo`).

#### 3. Argument validation

Check that all required arguments are provided. Exit with code 69 for missing arguments.

**run_unittests** expects 1 argument: `plain_modules/<module_name>`
**run_conformance_tests** expects 2 arguments: `plain_modules/<module_name>` and `conformance_tests/<module_name>/<functionality>`
**prepare_environment** expects 1 argument: `plain_modules/<module_name>`

**Bash (run_unittests / prepare_environment):**
```bash
if [ -z "$1" ]; then
  printf "Error: No build folder name provided.\n"
  printf "Usage: $0 <build_folder_name>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
```

**Bash (run_conformance_tests):**
```bash
if [ -z "$1" ]; then
  printf "Error: No build folder name provided.\n"
  printf "Usage: $0 <build_folder_name> <conformance_tests_folder>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

if [ -z "$2" ]; then
  printf "Error: No conformance tests folder name provided.\n"
  printf "Usage: $0 <build_folder_name> <conformance_tests_folder>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
```

**PowerShell (run_unittests / prepare_environment):**
```powershell
if ([string]::IsNullOrWhiteSpace($args[0])) {
    Write-Host "Error: No build folder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <build_folder_name>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}
```

**PowerShell (run_conformance_tests):**
```powershell
if ([string]::IsNullOrWhiteSpace($args[0])) {
    Write-Host "Error: No build folder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <build_folder_name> <conformance_tests_folder>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}

if ([string]::IsNullOrWhiteSpace($args[1])) {
    Write-Host "Error: No conformance tests folder name provided."
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <build_folder_name> <conformance_tests_folder>"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}
```

#### 4. Build subfolder staging

Scripts copy build output into a staging subfolder before running tests. The subfolder path convention is:

- **Python**: `.tmp/<subfolder_name>`
- **Java**: `.tmp/java_<subfolder_name>`
- **General pattern**: `.tmp/<lang_prefix>_<subfolder_name>` or `.tmp/<subfolder_name>`

The staging logic:
1. If the subfolder exists, clean it (delete contents).
2. If it doesn't exist, create it.
3. Copy build files into it.
4. `cd` into the subfolder.

**Bash:**
```bash
BUILD_SUBFOLDER=".tmp/$1"

if [ -d "$BUILD_SUBFOLDER" ]; then
  find "$BUILD_SUBFOLDER" -mindepth 1 -exec rm -rf {} +
else
  mkdir -p "$BUILD_SUBFOLDER"
fi

cp -R $1/* $BUILD_SUBFOLDER

cd "$BUILD_SUBFOLDER" 2>/dev/null
if [ $? -ne 0 ]; then
  printf "Error: Build folder '$BUILD_SUBFOLDER' does not exist.\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi
```

**PowerShell:**
```powershell
$BUILD_SUBFOLDER = ".tmp/$($args[0])"

if (Test-Path $BUILD_SUBFOLDER -PathType Container) {
    Get-ChildItem -Path $BUILD_SUBFOLDER | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $BUILD_SUBFOLDER -Force | Out-Null
}

Copy-Item -Path "$($args[0])\*" -Destination $BUILD_SUBFOLDER -Recurse -Force

try {
    Set-Location $BUILD_SUBFOLDER
} catch {
    Write-Host "Error: Build folder '$BUILD_SUBFOLDER' does not exist."
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
}
```

#### 5. VERBOSE support

Support a `VERBOSE` environment variable for optional debug output:

**Bash:**
```bash
if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
  printf "Preparing build subfolder: $BUILD_SUBFOLDER\n"
fi
```

**PowerShell:**
```powershell
if ($env:VERBOSE -eq 1) {
    Write-Host "Preparing build subfolder: $BUILD_SUBFOLDER"
}
```

#### 6. Test execution — capture output, print it, and propagate exit code

**CRITICAL:** The script **must** capture the full stdout+stderr trace from the test command and print it before exiting. This output is consumed by the pipeline to diagnose and fix failing tests. If the output is lost or suppressed, the pipeline cannot function. Always follow this exact pattern:

**Bash:**
```bash
output=$(<test_command> 2>&1)
exit_code=$?
printf "%s\n" "$output"
exit $exit_code
```

**PowerShell:**
```powershell
$output = & <test_command> 2>&1
$exit_code = $LASTEXITCODE
Write-Host $output
exit $exit_code
```

Use `printf "%s\n" "$output"` (not `echo`) to avoid issues with special characters in test traces. The full error trace, stack traces, assertion messages, and test names must all be visible in the script's output.

### Script-Type-Specific Patterns

#### run_unittests

Invoked as: `run_unittests_<lang>.sh plain_modules/<module_name>`

1. Validate 1 argument (`$1` = `plain_modules/<module_name>`).
2. Check environment (language/tool installed).
3. Stage build output in `.tmp/` subfolder — copy `$1/*` into the staging folder.
4. `cd` into the staging folder.
5. Run unit tests.
6. Propagate exit code.

#### run_conformance_tests

Invoked as: `run_conformance_tests_<lang>.sh plain_modules/<module_name> conformance_tests/<module_name>/<functionality>`

1. Validate 2 arguments (`$1` = `plain_modules/<module_name>`, `$2` = `conformance_tests/<module_name>/<functionality>`).
2. Check environment.
3. Stage build output in `.tmp/` subfolder — copy `$1/*` into the staging folder.
4. Create a separate conformance tests staging folder (e.g., `.tmp/<lang>_conformance`).
5. Copy conformance test files from `$2` into the conformance staging folder.
6. `cd` into the conformance staging folder.
7. If needed, run a build/install step before running tests (e.g., `mvn clean install -DskipTests`).
8. Run conformance tests. For Python-style projects, use `-s` to point the test runner at the conformance tests source. For Java-style, run tests directly in the conformance folder.
9. Check for "0 tests ran" edge case and fail if no tests were discovered.
10. Propagate exit code.

#### prepare_environment

Invoked as: `prepare_environment_<lang>.sh plain_modules/<module_name>`

This script does **not** use `.tmp/` staging. Instead it copies generated code into a **language-prefixed project folder** that already exists (or was previously created). The folder naming convention is `<lang>_<module_name>` (e.g., `java_plain_modules/myapp`, `flutter_plain_modules/myapp`).

1. Validate 1 argument (`$1` = `plain_modules/<module_name>`).
2. Check environment.
3. Derive the project folder name: `<LANG_PREFIX>_$1` (e.g., `java_$1`).
4. Check that the project folder exists. If not, exit with error code 2.
5. Copy build output from `$1/*` into the project folder.
6. `cd` into the project folder.
7. Run the build/install step (e.g., `mvn clean install -DskipTests`, `flutter pub get`, `npm install`).
8. Do **not** run tests.

**Bash example (Java prepare_environment):**
```bash
JAVA_BUILD_SUBFOLDER=java_$1

if [ ! -d "$JAVA_BUILD_SUBFOLDER" ]; then
  echo "Error: Main project folder '$JAVA_BUILD_SUBFOLDER' does not exist."
  exit 2
fi

cp -R $1/* $JAVA_BUILD_SUBFOLDER
printf "Copied from $1 to $JAVA_BUILD_SUBFOLDER...\n"

cd "$JAVA_BUILD_SUBFOLDER" 2>/dev/null
if [ $? -ne 0 ]; then
  printf "Error: Build folder '$JAVA_BUILD_SUBFOLDER' does not exist.\n"
  exit 2
fi

echo "Running build/install..."
mvn clean install -DskipTests
```

### Conflict Checking (Java-style projects only)

For languages where the build folder is incrementally built across multiple modules (e.g., Java with Maven), include conflict checking before copying:

```bash
temp_file=$(mktemp)

find "$1" -type f ! -name ".DS_Store" | while IFS= read -r file; do
  relative_path="${file#$1/}"
  if [ -e "$BUILD_SUBFOLDER/$relative_path" ]; then
    echo "Error: Implementation of the file '$relative_path' should not be changed as it is used by the other parts of the system."
    echo "CONFLICT" > "$temp_file"
  fi
done

if [ -f "$temp_file" ] && [ "$(cat "$temp_file")" = "CONFLICT" ]; then
  rm "$temp_file"
  exit 2
fi
rm -f "$temp_file"
echo "No conflicts found, proceeding with copy..."
```

Only add conflict checking when the user confirms the project has incremental/layered builds. For most languages (Python, Flutter, Go, Rust, Node), this is not needed.

## Phase 3 — Make Scripts Executable and Verify

After creating all scripts:

1. For `.sh` scripts: run `chmod +x` on all new files.
2. Read each created script back in full.
3. Verify:
   - [ ] Every script checks the environment and exits with code 69 if tools are missing, with a helpful message.
   - [ ] Every script validates its arguments and exits with code 69 if missing.
   - [ ] Staging folder logic follows the `.tmp/` convention.
   - [ ] Test commands are correct for the language.
   - [ ] **CRITICAL:** Test output (stdout+stderr) is captured and printed in full before exiting — the pipeline depends on this trace to diagnose failures.
   - [ ] Exit codes are propagated.
   - [ ] VERBOSE support is present.
   - [ ] Script format matches the user's OS (`.sh` for macOS/Linux, `.ps1` for Windows).
4. Present the summary of created files to the user.

## Phase 4 — Update config.yaml

After creating the scripts, update `config.yaml` to point to the new scripts. If `config.yaml` does not exist, create it.

The relevant fields are (use `.sh` or `.ps1` depending on the user's OS). The codeplain renderer automatically passes the correct `plain_modules/<module_name>` and `conformance_tests/<module_name>/<functionality>` arguments when invoking these scripts:

```yaml
unittests-script: test_scripts/run_unittests_<language>.sh
conformance-tests-script: test_scripts/run_conformance_tests_<language>.sh
prepare-environment-script: test_scripts/prepare_environment_<language>.sh
```

Only add entries for the script types that were created. Preserve any existing fields in `config.yaml` that are unrelated to the new scripts.
