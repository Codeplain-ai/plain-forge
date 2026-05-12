#!/bin/bash

UNRECOVERABLE_ERROR_EXIT_CODE=69

# Check if build folder name is provided
if [ -z "$1" ]; then
  printf "Error: No build folder name provided.\n"
  printf "Usage: $0 <build_folder_name> <conformance_tests_folder>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

# Check if conformance tests folder name is provided
if [ -z "$2" ]; then
  printf "Error: No conformance tests folder name provided.\n"
  printf "Usage: $0 <build_folder_name> <conformance_tests_folder>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

# Try to find Python interpreter (python3 first, then python)
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
else
    printf "Error: Python interpreter not found. Please install Python.\n"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

current_dir=$(pwd)

PYTHON_BUILD_SUBFOLDER=".tmp/$1"

if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
  printf "Preparing Python build subfolder: $PYTHON_BUILD_SUBFOLDER\n"
fi

rm -rf $PYTHON_BUILD_SUBFOLDER
mkdir -p $PYTHON_BUILD_SUBFOLDER

cp -R $1/* $PYTHON_BUILD_SUBFOLDER

# Move to the subfolder
cd "$PYTHON_BUILD_SUBFOLDER" 2>/dev/null

if [ $? -ne 0 ]; then
  printf "Error: Python build folder '$PYTHON_BUILD_SUBFOLDER' does not exist.\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

printf "Creating and activating virtual environment...\n"

# Time the virtual environment creation and activation
start_time=$(date +%s.%N)

VENV_DIR=".venv"

if ! $PYTHON_CMD -m venv "$VENV_DIR"; then
    printf "Error: Failed to create virtual environment in '$VENV_DIR'.\n"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

if [ $? -ne 0 ]; then
    printf "Error: Failed to activate virtual environment at '$VENV_DIR/bin/activate'.\n"
    exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

# Install requirements if requirements.txt exists
if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found. Cannot proceed with setting up requirements. The requirements may also already be installed"
fi

end_time=$(date +%s.%N)

# Calculate and display the time taken
duration=$(echo "$end_time - $start_time" | bc)
printf "Requirements setup completed in %.2f seconds\n\n" "$duration"

# Execute all Python conformance tests in the build folder
printf "Running Python conformance tests...\n\n"

output=$($PYTHON_CMD -m unittest discover -b -s "$current_dir/$2" 2>&1)
exit_code=$?

# Echo the original output
echo "$output"

# Check if no tests were discovered
if echo "$output" | grep -q "Ran 0 tests in"; then
    printf "\nError: No unittests discovered.\n"
    exit 1
fi

# Echo the original exit code of the unittest command
exit $exit_code