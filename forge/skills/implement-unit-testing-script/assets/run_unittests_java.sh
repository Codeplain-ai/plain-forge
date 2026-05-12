#!/bin/bash

# Check that Java 21 is installed
if ! /usr/libexec/java_home -v 21 >/dev/null 2>&1; then
  echo "Error: Java 21 is not installed."
  exit 69
fi

export JAVA_HOME=$(/usr/libexec/java_home -v 21)
java --version

# Check if subfolder name is provided
if [ -z "$1" ]; then
  echo "Error: No subfolder name provided."
  echo "Usage: $0 <subfolder_name>"
  exit 1
fi

# Define the path to the java build subfolder
WORKING_FOLDER=.tmp/$1

# Check if the java subfolder exists
if [ -d "$WORKING_FOLDER" ]; then
  # delete everything in the subfolder
  rm -rf "$WORKING_FOLDER"/*
else
  echo "Subfolder '$WORKING_FOLDER' does not exist. Creating it now..."
  mkdir -p "$WORKING_FOLDER"
fi


# copy all folders and files from the build folder to the subfolder
cp -R $1/* $WORKING_FOLDER
printf "Copied from $1 to $WORKING_FOLDER...\n"
# Move to the subfolder
cd "$WORKING_FOLDER" 2>/dev/null
printf "Moved to $WORKING_FOLDER...\n"
if [ $? -ne 0 ]; then
  echo "Error: Subfolder '$1' does not exist."
  exit 2
fi

# Execute all Java unittests in the subfolder
echo "Running Java unittests in $(pwd)..."
mvn test