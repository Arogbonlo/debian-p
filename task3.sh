#!/bin/bash

# Define variables
REPO_URL="https://github.com/indilib/indi-3rdparty.git"
LOCAL_DIR="$HOME/indi-3rdparty"
LOG_FILE="$HOME/indi_driver_info.log"
DEBUG_LOG="$HOME/indi_driver_debug.log"
EXCLUDE_FILE="$HOME/excluded_drivers.txt"  # File containing list of directories to ignore

# Function to log messages to the main log file
log() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Function to log debug messages to the debug log file
debug_log() {
  echo "$(date): $1" >> "$DEBUG_LOG"
}

# Increase Git buffer size for large repositories
git config --global http.postBuffer 5242880000
log "Increased Git buffer size to 5GB."

# Clone or update the repository
if [ ! -d "$LOCAL_DIR" ]; then
  log "Cloning repository to $LOCAL_DIR..."
  git clone "$REPO_URL" "$LOCAL_DIR" || {
    log "Failed to clone repository."
    exit 1
  }
else
  log "Updating existing repository in $LOCAL_DIR..."
  cd "$LOCAL_DIR" && git pull || {
    log "Failed to update repository."
    exit 1
  }
fi

# Navigate to the repository directory
cd "$LOCAL_DIR" || { log "Failed to change directory to $LOCAL_DIR."; exit 1; }

# Get list of excluded drivers if the file exists
if [ -f "$EXCLUDE_FILE" ]; then
  EXCLUDED_DRIVERS=$(cat "$EXCLUDE_FILE" | tr '\n' ' ')
  log "Excluding drivers from list: $EXCLUDED_DRIVERS"
fi

# Get the list of driver directories, excluding hidden and excluded ones
DRIVERS=$(find . -maxdepth 1 -type d -not -path './.*' -not -path '.' | sed 's|^\./||')
for EXCLUDED in $EXCLUDED_DRIVERS; do
  DRIVERS=$(echo "$DRIVERS" | grep -v "$EXCLUDED")
done

# Print header for output
printf "%-30s %-40s\n" "Driver" "Version" | tee -a "$LOG_FILE"
printf "%-30s %-40s\n" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..40})" | tee -a "$LOG_FILE"

# Function to extract version from various sources
extract_version() {
  local driver_dir="$1"
  local version=""

  # Try debian/changelog first
  if [ -f "$driver_dir/debian/changelog" ]; then
    version=$(head -n 1 "$driver_dir/debian/changelog" | sed -n 's/.*(\([0-9][0-9.:~+-]*\)).*/\1/p')
    debug_log "Version from debian/changelog: $version"
  fi

  # If not found, try CMakeLists.txt
  if [ -z "$version" ] && [ -f "$driver_dir/CMakeLists.txt" ]; then
    version=$(grep -i "set.version" "$driver_dir/CMakeLists.txt" | grep -v "CMAKE_MINIMUM_REQUIRED" | sed -n 's/.*VERSION[^0-9]\([0-9.]\+\).*/\1/p' | head -n 1)
    debug_log "Version from CMakeLists.txt: $version"
  fi

  # If still not found, try generic version search
  if [ -z "$version" ]; then
    version=$(grep -r -i "version" "$driver_dir" 2>/dev/null | grep -v "CMAKE_MINIMUM_REQUIRED" | grep -o '[0-9]\+\.[0-9]\+\(\.[0-9]\+\)*' | head -n 1)
    debug_log "Version from grep search: $version"
  fi

  echo "$version"
}

# Function to format version string
format_version_string() {
  local version="$1"
  local date="$2"
  local hash="$3"

  # Format date as YYYYMMDD
  local formatted_date=$(date -d "$date" +"%Y%m%d" 2>/dev/null)

  # Use the first 8 characters of the hash
  local short_hash=$(echo "$hash" | cut -c1-8)

  # Return formatted version string
  if [ -n "$version" ] && [ -n "$formatted_date" ] && [ -n "$short_hash" ]; then
    echo "${version}~git${formatted_date}.${short_hash}"
  else
    echo "N/A"
  fi
}

# Loop through each driver directory to retrieve version and git info
for DRIVER in $DRIVERS; do
  debug_log "Processing driver: $DRIVER"

  # Extract version
  VERSION=$(extract_version "$LOCAL_DIR/$DRIVER")
  [ -z "$VERSION" ] && VERSION="N/A"

  # Get latest commit hash and date for each driver
  HASH=$(git log -1 --format="%H" -- "$DRIVER" 2>/dev/null)
  DATE=$(git log -1 --format="%ad" --date=short -- "$DRIVER" 2>/dev/null)
  [ -z "$HASH" ] && HASH="N/A"
  [ -z "$DATE" ] && DATE="N/A"
  
  debug_log "Git hash for $DRIVER: $HASH"
  debug_log "Last commit date for $DRIVER: $DATE"

  # Format the final version string
  FINAL_VERSION=$(format_version_string "$VERSION" "$DATE" "$HASH")

  # Print and log the driver information
  printf "%-30s %-40s\n" "$DRIVER" "$FINAL_VERSION" | tee -a "$LOG_FILE"
done

log "Driver information extraction completed."
log "Debug information saved to $DEBUG_LOG"
