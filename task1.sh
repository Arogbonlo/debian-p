#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error on line $1: $2"
    exit 1
}

# Trap errors and call the handle_error function
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

# Path to the cloned repository
REPO_PATH=~/Desktop/debian/indi-3rdparty

# Ensure the repository exists locally
if [ ! -d "$REPO_PATH" ]; then
    echo "Repository path does not exist: $REPO_PATH"
    exit 1
fi

# Navigate to the repository
cd "$REPO_PATH" || exit

# Get list of drivers and their git version and hash
for driver in $(ls -d */); do
    cd "$driver" || {
        echo "Failed to enter directory $driver"
        continue
    }

    # Ensure it's a git repository
    if [ -d ".git" ]; then
        
        # Get the version and latest git hash
        DRIVER_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "No tags")
        DRIVER_HASH=$(git rev-parse HEAD 2>/dev/null || echo "No git hash found")
        echo "Driver: ${driver%/}, Version: $DRIVER_VERSION, Git Hash: $DRIVER_HASH"
    else
        echo "Skipping $driver (not a git repository)"
    fi
    
    # Go back to the main directory to continue with the next driver
    cd "$REPO_PATH" || exit
done
