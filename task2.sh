#!/bin/bash

# Define variables
LOG_FILE="$HOME/debian_driver_update.log"
PROCESSED_FILE="$HOME/debian_processed_drivers.log"
RELEASE=$(lsb_release -sc)

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

# Fetch a list of installed drivers available as Debian packages
display "Fetching list of installed drivers (Debian packages)..."
log "Fetching list of installed drivers (Debian packages)..."
INSTALLED_DRIVERS=$(dpkg-query -W -f='${binary:Package}\n' | grep -i "driver")

if [ -z "$INSTALLED_DRIVERS" ]; then
  display "No drivers found installed via Debian packages."
  log "No drivers found installed via Debian packages."
  exit 0
fi

# Loop through each installed driver and get its version and source repository
for DRIVER in $INSTALLED_DRIVERS; do
  display "Checking driver: $DRIVER"
  log "Checking driver: $DRIVER"

  # Get the installed version of the current driver
  VERSION=$(dpkg-query -W -f='${Version}' "$DRIVER") || {
    display "Failed to get version for $DRIVER."
    log "Failed to get version for $DRIVER."
    continue
  }

  # Check if this driver has already been processed
  if grep -i -q "$DRIVER:$VERSION" "$PROCESSED_FILE"; then
    display "Driver $DRIVER (Version: $VERSION) has already been processed."
    log "Driver $DRIVER (Version: $VERSION) has already been processed."
  else
    # Download the package source using the current release
    display "Downloading source for $DRIVER (Release: $RELEASE)..."
    log "Downloading source for $DRIVER (Release: $RELEASE)..."
    apt-get source -t "$RELEASE" "$DRIVER" >/dev/null 2>&1  # Download source using the detected release
    SRC_DIR=$(find . -maxdepth 1 -type d -name "$DRIVER-*")  # Find the source directory

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
