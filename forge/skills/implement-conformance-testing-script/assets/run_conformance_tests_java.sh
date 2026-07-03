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

# Resolve the conformance tests folder to an absolute path so it can be used
# after changing into the working folder ($2 may be relative to the invocation
# directory on older renderers; newer renderers pass it as an absolute path).
case "$2" in
  /*) CONFORMANCE_TESTS_SOURCE="$2" ;;
  *)  CONFORMANCE_TESTS_SOURCE="$current_dir/$2" ;;
esac

tree "$CONFORMANCE_TESTS_SOURCE"

# Working folders live in the system temp directory. $1 and $2 may be absolute
# paths, so only their basenames are used to build the working folder names.
JAVA_BUILD_SUBFOLDER="/tmp/java_$(basename "$1")"
CONFORMANCE_TESTS_FOLDER="/tmp/java_conformance_$(basename "$2")"

trap 'rm -rf "$JAVA_BUILD_SUBFOLDER" "$CONFORMANCE_TESTS_FOLDER"' EXIT

if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
  printf "Preparing Java build subfolder: $JAVA_BUILD_SUBFOLDER\n"
fi

rm -rf "$JAVA_BUILD_SUBFOLDER"
mkdir -p "$JAVA_BUILD_SUBFOLDER"

cp -R "$1"/* "$JAVA_BUILD_SUBFOLDER"
printf "Copied from $1 to $JAVA_BUILD_SUBFOLDER...\n"

# Move to the subfolder
cd "$JAVA_BUILD_SUBFOLDER" 2>/dev/null
printf "Moved to $JAVA_BUILD_SUBFOLDER...\n"

if [ $? -ne 0 ]; then
  printf "Error: Java build folder '$JAVA_BUILD_SUBFOLDER' does not exist.\n"
  exit 2
fi

echo "Runinng maven install in $(pwd)..."
output=$(mvn clean install -DskipTests 2>&1)
exit_code=$?

# If there was an error, print the output and exit with the error code
if [ $exit_code -ne 0 ]; then
    echo "Command failed: mvn clean install -DskipTests"
    echo "Error: Running maven build failed with exit code $exit_code"
    echo "Output: $output"    
    exit $exit_code
fi

cd "$current_dir" 2>/dev/null
printf "Moved to $current_dir...\n"
printf "Preparing Java conformance tests subfolder: $CONFORMANCE_TESTS_FOLDER\n"

rm -rf "$CONFORMANCE_TESTS_FOLDER"
mkdir -p "$CONFORMANCE_TESTS_FOLDER"

cp -R "$CONFORMANCE_TESTS_SOURCE"/* "$CONFORMANCE_TESTS_FOLDER"
printf "Copied from $CONFORMANCE_TESTS_SOURCE to $CONFORMANCE_TESTS_FOLDER...\n"

# Move to the subfolder
cd "$CONFORMANCE_TESTS_FOLDER" 2>/dev/null
printf "Moved to $CONFORMANCE_TESTS_FOLDER...\n"

if [ $? -ne 0 ]; then
  printf "Error: Java conformance tests folder '$CONFORMANCE_TESTS_FOLDER' does not exist.\n"
  exit 2
fi

echo "Runinng maven install in $(pwd)..."
output=$(mvn clean install -DskipTests 2>&1)
exit_code=$?

# If there was an error, print the output and exit with the error code
if [ $exit_code -ne 0 ]; then
    echo "Command failed: mvn clean install -DskipTests"
    echo "Error: Running maven build failed with exit code $exit_code"
    echo "Output: $output"    
    exit $exit_code
fi

# Execute all Java unittests in the subfolder
echo "Running Java unittests in $(pwd)..."
output=$(mvn test 2>&1)
exit_code=$?

# If there was an error, print the output and exit with the error code
if [ $exit_code -ne 0 ]; then
    echo "$output"
    exit $exit_code
fi

# Echo the original exit code of the unittest command
exit $exit_code