#!/bin/bash

# Define variables
REPO_URL="https://github.com/indilib/indi-3rdparty.git"
LOCAL_DIR="$HOME/indi-3rdparty"
LOG_FILE="$HOME/indi_driver_update.log"

# Function to log messages to the file
log() {
  echo "$(date): $1" >> "$LOG_FILE"
}

# Function to display messages in the terminal
display() {
  echo "$1"
}

# Increase Git buffer size to handle large repositories
git config --global http.postBuffer 5242880000
log "Increased Git buffer size to 500MB."

# Ensure the directory exists, clone if it does not
if [ ! -d "$LOCAL_DIR" ]; then
  display "Directory $LOCAL_DIR does not exist. Cloning repository..."
  log "Directory $LOCAL_DIR does not exist. Cloning repository..."

  # Clone repository with shallow depth, and limit to 1 thread
  git clone --depth 1 --jobs 1 "$REPO_URL" "$LOCAL_DIR" --progress || {
    display "Failed to clone repository."
    log "Failed to clone repository."
    exit 1
  }
else
  display "Directory $LOCAL_DIR already exists, pulling latest changes..."
  log "Directory $LOCAL_DIR already exists, pulling latest changes..."
  cd "$LOCAL_DIR" && git pull || {
    display "Failed to pull latest changes."
    log "Failed to pull latest changes."
    exit 1
  }
fi

# Navigate to the directory
cd "$LOCAL_DIR" || { display "Failed to change directory to $LOCAL_DIR."; log "Failed to change directory to $LOCAL_DIR."; exit 1; }

# Fetch driver information
display "Fetching driver information from the repository..."
log "Fetching driver information from the repository."

# Get the list of driver directories
DRIVERS=$(find . -maxdepth 1 -type d -not -path './.*' -not -path '.' | sed 's|^\./||')

# Loop through each driver and get its version and latest git hash
for DRIVER in $DRIVERS; do
  display "Checking driver: $DRIVER"
  log "Checking driver: $DRIVER"

  # Navigate into driver directory
  cd "$DRIVER" || { display "Failed to change directory to $DRIVER."; log "Failed to change directory to $DRIVER."; continue; }

  # Get the latest git hash for the current driver
  HASH=$(git log -1 --format="%H" 2>/dev/null) || {
    display "Failed to get git hash for $DRIVER."
    log "Failed to get git hash for $DRIVER."
    continue
  }

  # Extract version from CMakeLists.txt or a similar file if it exists
  VERSION=$(grep -m 1 "VERSION" CMakeLists.txt 2>/dev/null | cut -d ' ' -f 2 | tr -d '()') || {
    VERSION="N/A"
    log "No version info found for $DRIVER."
  }

  # If version was found, log and display
  if [ -n "$VERSION" ]; then
    display "Driver: $DRIVER, Version: $VERSION, Hash: $HASH"
    log "Driver: $DRIVER, Version: $VERSION, Hash: $HASH"
  else
    display "Version not found for driver $DRIVER."
    log "Version not found for driver $DRIVER."
  fi

  # Go back to the parent directory
  cd ..
done

display "Driver update check completed."
log "Driver update check completed."