#!/bin/bash

UNRECOVERABLE_ERROR_EXIT_CODE=69

# Check if source folder name is provided
if [ -z "$1" ]; then
  echo "Error: No source folder name provided."
  echo "Usage: $0 <source_folder_name>"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

current_dir=$(pwd)
SOURCE_FOLDER=$1
BUILD_SUBFOLDER=.tmp/python_build_unittests

echo "Current directory: $current_dir"
echo "Source folder: $SOURCE_FOLDER"
echo "--------------------------------"

# Prepare clean build subfolder
if [ -d "$BUILD_SUBFOLDER" ]; then
  rm -rf "$BUILD_SUBFOLDER"
fi
mkdir -p "$BUILD_SUBFOLDER"

# Copy source code and tests to build folder
cp -R $SOURCE_FOLDER/* "$BUILD_SUBFOLDER/"

# Move to the subfolder
cd "$BUILD_SUBFOLDER" || exit $UNRECOVERABLE_ERROR_EXIT_CODE

printf "Setting up Python environment and dependencies...\n"

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
if [ -f "requirements.txt" ]; then
    pip install --upgrade pip
    pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found. Dependencies might be missing."
fi

pip install pytest

# Execute all Python unittests
echo "Running Python unittests in $BUILD_SUBFOLDER..."

# Use timeout to prevent hanging tests
output=$(timeout 120s python3 -m pytest -v -x 2>&1)
exit_code=$?

# Check for timeout
if [ $exit_code -eq 124 ]; then
    printf "\nError: Unittests timed out after 120 seconds.\n"
    exit $exit_code
fi

# Echo the original output
echo "$output"

# Deactivate venv
deactivate

# Return the exit code of the unittest command
exit $exit_code