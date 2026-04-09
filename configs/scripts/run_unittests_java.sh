#!/bin/bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
java --version

# Check if subfolder name is provided
if [ -z "$1" ]; then
  echo "Error: No subfolder name provided."
  echo "Usage: $0 <subfolder_name>"
  exit 1
fi

# Define the path to the java build subfolder
JAVA_SUBFOLDER=.tmp/java_$1

# Check if the java subfolder exists
if [ -d "$JAVA_SUBFOLDER" ]; then
  # delete everything in the subfolder
  rm -rf "$JAVA_SUBFOLDER"/*
else
  echo "Error: Subfolder '$JAVA_SUBFOLDER' does not exist. Creating it now..."
  mkdir -p "$JAVA_SUBFOLDER"
fi

# Check for conflicts before copying build files
# if any file from the build folder would overwrite a file already copied from referenced_files, fail with an error

# Create a temporary file to store conflicts
temp_file=$(mktemp)

find "$1" -type f ! -name ".DS_Store" | while IFS= read -r file; do
  # Get the relative path from the build directory
  relative_path="${file#$1/}"
  if [ -e "$JAVA_SUBFOLDER/$relative_path" ]; then
    echo "Error: Implementation of the file '$relative_path' should not be changed as it is used by the other parts of the system."
    echo "CONFLICT" > "$temp_file"
  fi
done

# Check if conflicts were found
if [ -f "$temp_file" ] && [ "$(cat "$temp_file")" = "CONFLICT" ]; then
  rm "$temp_file"
  exit 2
fi

rm -f "$temp_file"
echo "No conflicts found, proceeding with copy..."

# copy all folders and files from the build folder to the subfolder
cp -R $1/* $JAVA_SUBFOLDER
printf "Copied from $1 to $JAVA_SUBFOLDER...\n"
# Move to the subfolder
cd "$JAVA_SUBFOLDER" 2>/dev/null
printf "Moved to $JAVA_SUBFOLDER...\n"
if [ $? -ne 0 ]; then
  echo "Error: Subfolder '$1' does not exist."
  exit 2
fi

# Execute all Java unittests in the subfolder

# echo "Runinng maven build..."
# output=$(mvn clean install -DskipTests 2>&1)
# exit_code=$?
# 
# # If there was an error, print the output and exit with the error code
# if [ $exit_code -ne 0 ]; then
#     echo "Command failed: mvn clean install -DskipTests"
#     echo "Error: Running maven build failed with exit code $exit_code"
#     echo "Output: $output"    
#     exit $exit_code
# fi

# Execute all Java unittests in the subfolder
echo "Running Java unittests in $(pwd)..."
mvn test