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
  display "'unstable' is not configured. Please configure the 'unstable' source manually."
  log "'unstable' is not configured. Please configure the 'unstable' source manually."
else
  display "'unstable' sources are already configured."
  log "'unstable' sources are already configured."
fi

# Fetch a list of drivers from the Debian repository
display "Fetching list of drivers from Debian repository for release $RELEASE..."
log "Fetching list of drivers from Debian repository for release $RELEASE..."

# Use apt-cache to search for available driver packages
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
    # Display the driver information
    display "Driver: $DRIVER, Version: $VERSION"
    log "Driver: $DRIVER, Version: $VERSION"

    # Record the driver as processed
    echo "$DRIVER:$VERSION" >> "$PROCESSED_FILE"
  fi
done

display "Driver version check completed."
log "Driver version check completed."
