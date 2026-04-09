#!/bin/bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
java --version

# Check if build folder name is provided
if [ -z "$1" ]; then
  printf "Error: No build folder name provided.\n"
  printf "Usage: $0 <build_folder_name> <conformance_tests_folder>\n"
  exit 1
fi

# Check if conformance tests folder name is provided
if [ -z "$2" ]; then
  printf "Error: No conformance tests folder name provided.\n"
  printf "Usage: $0 <build_folder_name> <conformance_tests_folder>\n"
  exit 1
fi

current_dir=$(pwd)
printf "Current directory: $current_dir\n"

tree $2

JAVA_BUILD_SUBFOLDER=.tmp/java_$1

# if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
#   printf "Preparing Java build subfolder: $JAVA_BUILD_SUBFOLDER\n"
# fi
# 
# # Check if the go build subfolder exists
# if [ -d "$JAVA_BUILD_SUBFOLDER" ]; then
#   # Find and delete all files and folders
#   find "$JAVA_BUILD_SUBFOLDER" -mindepth 1 -exec rm -rf {} +
# 
#   if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
#     printf "Cleanup completed.\n"
#   fi
# else
#   if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
#     printf "Subfolder does not exist. Creating it...\n"
#   fi
# 
#   mkdir $JAVA_BUILD_SUBFOLDER
# fi
# 
# cp -R $1/* $JAVA_BUILD_SUBFOLDER
# printf "Copied from $1 to $JAVA_BUILD_SUBFOLDER...\n"
# 
# # Move to the subfolder
# cd "$JAVA_BUILD_SUBFOLDER" 2>/dev/null
# printf "Moved to $JAVA_BUILD_SUBFOLDER...\n"
# 
# if [ $? -ne 0 ]; then
#   printf "Error: Java build folder '$JAVA_BUILD_SUBFOLDER' does not exist.\n"
#   exit 2
# fi

# echo "Runinng maven install in $(pwd)..."
# output=$(mvn clean install -DskipTests 2>&1)
# exit_code=$?

# If there was an error, print the output and exit with the error code
# if [ $exit_code -ne 0 ]; then
#     echo "Command failed: mvn clean install -DskipTests"
#     echo "Error: Running maven build failed with exit code $exit_code"
#     echo "Output: $output"    
#     exit $exit_code
# fi

CONFORMANCE_TESTS_FOLDER=.tmp/java_conformance

cd "$current_dir" 2>/dev/null
printf "Moved to $current_dir...\n"
printf "Preparing Java conformance tests subfolder: $CONFORMANCE_TESTS_FOLDER\n"

# Check if the go build subfolder exists
if [ -d "$CONFORMANCE_TESTS_FOLDER" ]; then
  # Find and delete all files and folders
  find "$CONFORMANCE_TESTS_FOLDER" -mindepth 1 -exec rm -rf {} +

  if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
    printf "Cleanup completed.\n"
  fi
else
  # print the current directory
  printf "Current directory: $(pwd)\n"

  printf "Subfolder does not exist. Creating it...\n"
  mkdir -p $CONFORMANCE_TESTS_FOLDER
fi

cp -R $2/* $CONFORMANCE_TESTS_FOLDER
printf "Copied from $2 to $CONFORMANCE_TESTS_FOLDER...\n"

# Move to the subfolder
cd "$CONFORMANCE_TESTS_FOLDER" 2>/dev/null
printf "Moved to $CONFORMANCE_TESTS_FOLDER...\n"

if [ $? -ne 0 ]; then
  printf "Error: Java conformance tests folder '$CONFORMANCE_TESTS_FOLDER' does not exist.\n"
  exit 2
fi

echo "Runinng maven install in $(pwd)..."
mvn clean install -DskipTests

echo "Running Java unittests in $(pwd)..."
mvn test
