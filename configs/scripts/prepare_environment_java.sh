#!/bin/bash

# Export Java 21
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
java --version

# Check if build folder name is provided
if [ -z "$1" ]; then
  printf "Error: No build folder name provided.\n"
  printf "Usage: $0 <build_folder_name>\n"
  exit 1
fi

JAVA_BUILD_SUBFOLDER=.tmp/java_$1

if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
  printf "Copying generated code to main project folder: $JAVA_BUILD_SUBFOLDER\n"
fi

# Check if the main project folder exists
if [ ! -d "$JAVA_BUILD_SUBFOLDER" ]; then
  echo "Error: Main project folder '$JAVA_BUILD_SUBFOLDER' does not exist."
  exit 2
fi

cp -R $1/* $JAVA_BUILD_SUBFOLDER
printf "Copied from $1 to $JAVA_BUILD_SUBFOLDER...\n"

# Move to the subfolder
cd "$JAVA_BUILD_SUBFOLDER" 2>/dev/null
printf "Moved to $JAVA_BUILD_SUBFOLDER...\n"

if [ $? -ne 0 ]; then
  printf "Error: Java build folder '$JAVA_BUILD_SUBFOLDER' does not exist.\n"
  exit 2
fi

echo "Runinng maven install in the build folder..."
# mvn clean install -Dspring-boot.repackage.skip=true -DskipTests
mvn clean install -DskipTests
