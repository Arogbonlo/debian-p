#!/bin/bash

# Set variables
PACKAGE_LIST_FILE="package_list.txt"  # Temporary file to store package list
REPO_BASE_PATH="https://github.com/indilib/indi-3rdparty.git"         # Base path where Git repositories are located

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Update package list
echo "Updating package list..."
if ! sudo apt update; then
    handle_error "Failed to update package list."
fi

# Get the list of installed packages and filter for 3rd-party packages
echo "Retrieving installed 3rd-party packages..."
if ! dpkg-query -W -f='${Package} ${Version}\n' | grep -i 'indi3rd-party' > "$PACKAGE_LIST_FILE"; then
    handle_error "Failed to retrieve package list."
fi

# Check if any packages were found
if [ ! -s "$PACKAGE_LIST_FILE" ]; then
    handle_error "No 3rd-party packages found."
fi

# Loop through each package to get version and git hash
echo "Gathering version and git hash information for each package..."
while read -r line; do
    PACKAGE_NAME=$(echo "$line" | awk '{print $1}')
    DEBIAN_VERSION=$(echo "$line" | awk '{print $2}')

    # Construct the path to the Git repository for this package
    GIT_REPO_PATH="$REPO_BASE_PATH/$PACKAGE_NAME"

    # Check if the directory exists before attempting to get the Git hash
    if [ -d "$GIT_REPO_PATH" ]; then
        # Get the latest commit hash from the git repository
        GIT_HASH=$(git -C "$GIT_REPO_PATH" rev-parse HEAD 2>/dev/null)
        if [ $? -ne 0 ]; then
            GIT_HASH="N/A"  # If there's an error getting the hash, set it to N/A
        fi
    else
        GIT_HASH="N/A"  # If the directory doesn't exist, set it to N/A
    fi

    # Output driver information
    echo "Package: $PACKAGE_NAME, Debian Version: $DEBIAN_VERSION, Git Hash: $GIT_HASH"
done < "$PACKAGE_LIST_FILE"

# Clean up temporary file only if it exists
if [ -f "$PACKAGE_LIST_FILE" ]; then
    rm "$PACKAGE_LIST_FILE"
fi

echo "Script completed successfully."