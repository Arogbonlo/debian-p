#!/bin/bash

# Define variables
LOG_FILE="$HOME/debian_driver_update.log"
PROCESSED_FILE="$HOME/debian_processed_drivers.log"
RELEASE="unstable"  # Set to use the unstable release

# Function to log messages to the file
log() {
  echo "$(date): $1" >> "$LOG_FILE"
}

# Function to display messages in the terminal
display() {
  echo "$1"
}

# Ensure the processed drivers log file exists
if [ ! -f "$PROCESSED_FILE" ]; then
  touch "$PROCESSED_FILE"
fi

# Check if unstable is configured in any sources.list or .list file
display "Checking if the 'unstable' sources are configured..."
log "Checking if the 'unstable' sources are configured..."

if ! grep -qr "deb .* unstable" /etc/apt/sources.list /etc/apt/sources.list.d/*.list; then
  # Unstable not found, adding it to /etc/apt/sources.list.d/unstable.list
  display "'unstable' is not configured. Adding 'unstable' sources to /etc/apt/sources.list.d/unstable.list."
  log "'unstable' is not configured. Adding 'unstable' sources to /etc/apt/sources.list.d/unstable.list."
  echo "deb http://deb.debian.org/debian unstable main contrib non-free" | sudo tee -a /etc/apt/sources.list.d/unstable.list
  echo "deb-src http://deb.debian.org/debian unstable main contrib non-free" | sudo tee -a /etc/apt/sources.list.d/unstable.list
else
  display "'unstable' sources are already configured."
  log "'unstable' sources are already configured."
fi

# Update the package cache
display "Updating package cache for 'unstable' sources..."
log "Updating package cache for 'unstable' sources..."
sudo apt-get update -o Dir::Etc::sourcelist="/etc/apt/sources.list.d/unstable.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

# Fetch a list of drivers from the Debian repository
display "Fetching list of drivers from Debian repository for release $RELEASE..."
log "Fetching list of drivers from Debian repository for release $RELEASE..."

# Use apt-cache search to fetch available driver packages
DRIVER_PACKAGES=$(apt-cache search "driver" | awk '{print $1}')

if [ -z "$DRIVER_PACKAGES" ]; then
  display "No drivers found in the repository for release $RELEASE."
  log "No drivers found in the repository for release $RELEASE."
  exit 0
fi

# Loop through each package to fetch version and check if processed
for DRIVER in $DRIVER_PACKAGES; do
  display "Checking driver package: $DRIVER"
  log "Checking driver package: $DRIVER"

  # Get the latest version from the changelog or repository
  VERSION=$(apt-cache madison "$DRIVER" | head -n 1 | awk '{print $3}') || {
    display "Failed to get version for $DRIVER."
    log "Failed to get version for $DRIVER."
    continue
  }

  # Check if this driver has already been processed
  if grep -i -q "$DRIVER:$VERSION" "$PROCESSED_FILE"; then
    display "Driver $DRIVER (Version: $VERSION) has already been processed."
    log "Driver $DRIVER (Version: $VERSION) has already been processed."
  else
    # Download the package source using the detected release
    display "Downloading source for $DRIVER (Release: $RELEASE)..."
    log "Downloading source for $DRIVER (Release: $RELEASE)..."
    apt-get source -t "$RELEASE" "$DRIVER" >/dev/null 2>&1  # Download source using the "unstable" release
    SRC_DIR=$(find . -maxdepth 1 -type d -name "$DRIVER-*")  # to find the source directory

    # Log and display the driver information
    display "Driver: $DRIVER, Version: $VERSION"
    log "Driver: $DRIVER, Version: $VERSION"

    # Record the driver as processed
    echo "$DRIVER:$VERSION" >> "$PROCESSED_FILE"

    # Clean up the downloaded source directory
    rm -rf "$SRC_DIR"
  fi
done

display "Driver version check completed."
log "Driver version check completed."
