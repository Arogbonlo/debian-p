#!/bin/bash


# Define constants
REPO_URL="https://github.com/indilib/indi-3rdparty.git"
CLONE_DIR="/tmp/thirdparty-drivers"
LOG_FILE="/var/log/driver_version_fetch.log"
PACKAGE_NAME="indi-armadillo-platypus"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    log_message "Error: $1"
    exit 1
}

# Clone the repository
clone_repository() {
    if [ -d "$CLONE_DIR" ]; then
        log_message "Removing existing clone directory."
        rm -rf "$CLONE_DIR" || handle_error "Failed to remove existing clone directory."
    fi

    log_message "Cloning repository from $REPO_URL."
    git clone "$REPO_URL" "$CLONE_DIR" || handle_error "Failed to clone repository."
}

# Fetch the driver version from debian/changelog
fetch_driver_version() {
    local changelog_file="$CLONE_DIR/debian/changelog"
    
    if [ ! -f "$changelog_file" ]; then
        handle_error "Changelog file not found: $changelog_file"
    fi

    log_message "Fetching driver version from $changelog_file."
    local version=$(grep -A 1 "$PACKAGE_NAME" "$changelog_file" | grep -oP '\d+\.\d+\.\d+~git\S*' | head -n 1)
    
    if [ -z "$version" ]; then
        handle_error "Failed to extract version from changelog."
    fi

    echo "$version"
}

# Get the latest git hash
fetch_latest_git_hash() {
    log_message "Fetching latest git hash."
    local latest_hash=$(git -C "$CLONE_DIR" rev-parse HEAD)
    
    if [ -z "$latest_hash" ]; then
        handle_error "Failed to retrieve latest git hash."
    fi

    echo "$latest_hash"
}

# Main execution flow
log_message "Starting driver version fetch script."

clone_repository
driver_version=$(fetch_driver_version)
latest_hash=$(fetch_latest_git_hash)

log_message "Driver Version: $driver_version"
log_message "Latest Git Hash: $latest_hash"

# Clean up
log_message "Cleaning up clone directory."
rm -rf "$CLONE_DIR" || handle_error "Failed to remove clone directory."

log_message "Script completed successfully."
exit 0