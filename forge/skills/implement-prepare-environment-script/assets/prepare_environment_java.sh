#!/bin/bash

# Check that Java 21 is installed
if ! /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
  printf "Error: Java 21 is not installed.\n"
  exit 69
fi

export JAVA_HOME=$(/usr/libexec/java_home -v 21)
java --version

# Check if build folder name is provided
if [ -z "$1" ]; then
  printf "Error: No build folder name provided.\n"
  printf "Usage: $0 <build_folder_name>\n"
  exit 1
fi

JAVA_BUILD_SUBFOLDER=.tmp/$1

if [ "${VERBOSE:-}" -eq 1 ] 2>/dev/null; then
  printf "Copying generated code to main project folder: $JAVA_BUILD_SUBFOLDER\n"
fi

rm -rf $JAVA_BUILD_SUBFOLDER
mkdir -p $JAVA_BUILD_SUBFOLDER

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

mvn clean install -DskipTests