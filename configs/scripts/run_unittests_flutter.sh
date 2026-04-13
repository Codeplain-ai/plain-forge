#!/bin/bash

UNRECOVERABLE_ERROR_EXIT_CODE=69

if [ -z "$1" ]; then
  echo "Error: No source folder name provided."
  echo "Usage: $0 <source_folder_name>"
  exit $UNRECOVERABLE_ERROR_EXIT_CODE
fi

current_dir=$(pwd)
SOURCE_FOLDER=$1
BUILD_SUBFOLDER=.tmp/flutter_build_unittests

echo "Current directory: $current_dir"
echo "Source folder: $SOURCE_FOLDER"
echo "--------------------------------"

if [ -d "$BUILD_SUBFOLDER" ]; then
  rm -rf "$BUILD_SUBFOLDER"
fi
mkdir -p "$BUILD_SUBFOLDER"

cp -R $SOURCE_FOLDER/* "$BUILD_SUBFOLDER/"

cd "$BUILD_SUBFOLDER" || exit $UNRECOVERABLE_ERROR_EXIT_CODE

printf "Resolving Flutter dependencies...\n"

if [ -f "pubspec.yaml" ]; then
    flutter pub get
else
    echo "Warning: pubspec.yaml not found. Dependencies might be missing."
fi

echo "Running Flutter unittests in $BUILD_SUBFOLDER..."

output=$(timeout 120s flutter test --reporter expanded 2>&1)
exit_code=$?

if [ $exit_code -eq 124 ]; then
    printf "\nError: Unittests timed out after 120 seconds.\n"
    exit $exit_code
fi

echo "$output"

exit $exit_code
