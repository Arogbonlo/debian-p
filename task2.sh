#!/bin/bash

# Define variables
LOG_FILE="$HOME/debian_driver_update.log"
PROCESSED_FILE="$HOME/debian_processed_drivers.log"

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
  if grep -q "$DRIVER:$VERSION" "$PROCESSED_FILE"; then
    display "Driver $DRIVER (Version: $VERSION) has already been processed."
    log "Driver $DRIVER (Version: $VERSION) has already been processed."
  else
    # Download the package source to look for VCS information
    display "Downloading source for $DRIVER..."
    log "Downloading source for $DRIVER..."
    apt-get source "$DRIVER" >/dev/null 2>&1  # Download source without output
    SRC_DIR=$(find . -maxdepth 1 -type d -name "$DRIVER-*")  # Find the source directory

    # Look for VCS information in debian/control or debian/copyright
    VCS_URL=$(grep -E 'Vcs-Git|Vcs-Browser' "$SRC_DIR/debian/control" 2>/dev/null | head -n 1 | awk '{print $2}')
    
    if [ -n "$VCS_URL" ]; then
      display "Found VCS URL for $DRIVER: $VCS_URL"
      log "Found VCS URL for $DRIVER: $VCS_URL"

      # Optionally, clone the repository and get the latest git hash
      git clone "$VCS_URL" "${DRIVER}_source" >/dev/null 2>&1
      if [ -d "${DRIVER}_source/.git" ]; then
        HASH=$(git -C "${DRIVER}_source" log -1 --format="%H") || {
          display "Failed to get git hash for $DRIVER."
          log "Failed to get git hash for $DRIVER."
          HASH="N/A"
        }
      else
        HASH="N/A"
        display "Git repository not found after cloning for $DRIVER."
        log "Git repository not found after cloning for $DRIVER."
      fi
      # Clean up cloned repo
      rm -rf "${DRIVER}_source"
    else
      HASH="N/A"
      display "No VCS information found for $DRIVER."
      log "No VCS information found for $DRIVER."
    fi

    # Log and display the driver information
    display "Driver: $DRIVER, Version: $VERSION, Git Hash: $HASH"
    log "Driver: $DRIVER, Version: $VERSION, Git Hash: $HASH"

    # Record the driver as processed
    echo "$DRIVER:$VERSION:$HASH" >> "$PROCESSED_FILE"

    # Clean up the downloaded source directory
    rm -rf "$SRC_DIR"
  fi
done

display "Driver version and git hash check commpleted."
log "Driver version and git hash check completed."
