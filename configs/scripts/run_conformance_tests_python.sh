#!/bin/bash

UNRECOVERABLE_ERROR_EXIT_CODE=69

# Check if source folder name is provided
if [ -z "$1" ]; then
  printf "Error: No source folder name provided.\n"
  printf "Usage: $0 <source_folder_name> <conformance_tests_folder>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

# Check if conformance tests folder name is provided
if [ -z "$2" ]; then
  printf "Error: No conformance tests folder name provided.\n"
  printf "Usage: $0 <source_folder_name> <conformance_tests_folder>\n"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

current_dir=$(pwd)
SOURCE_FOLDER=$1
CONFORMANCE_TESTS_DIR=$2
BUILD_SUBFOLDER=.tmp/python_build_conformance

echo "Current directory: $current_dir"
echo "Source folder: $SOURCE_FOLDER"
echo "Conformance tests: $CONFORMANCE_TESTS_DIR"
echo "--------------------------------"

# Prepare clean build subfolder
if [ -d "$BUILD_SUBFOLDER" ]; then
  rm -rf "$BUILD_SUBFOLDER"
fi
mkdir -p "$BUILD_SUBFOLDER"

# Copy source code to build folder
cp -R $SOURCE_FOLDER/* "$BUILD_SUBFOLDER/"

# Move to the subfolder
cd "$BUILD_SUBFOLDER" || exit $UNRECOVERABLE_ERROR_EXIT_CODE

printf "Setting up Python environment for conformance testing...\n"

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found."
fi

pip install pytest

# Execute all Python conformance tests
printf "Running Conformance Tests...\n\n"

output=$(python3 -m pytest -v -x "$current_dir/$CONFORMANCE_TESTS_DIR" 2>&1)
exit_code=$?

# Echo the test output
echo "$output"

# Check if no tests were discovered
if echo "$output" | grep -q "no tests ran"; then
    printf "\nError: No conformance tests were discovered in $CONFORMANCE_TESTS_DIR.\n"
    exit 1
fi

# Deactivate venv
deactivate

# Return the exit code of the unittest command
exit $exit_code