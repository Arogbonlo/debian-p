#!/bin/bash

# Define common variables
REPO_URL="https://github.com/indilib/indi-3rdparty.git"
LOCAL_DIR="$HOME/indi-3rdparty"
LOG_FILE="$HOME/indi_driver_info.log"
DEBUG_LOG="$HOME/indi_driver_debug.log"
EXCLUDE_FILE="$HOME/excluded_drivers.txt"
PROCESSED_FILE="$HOME/debian_processed_drivers.log"
RELEASE="unstable"

# Ensure the processed drivers log file exists
if [ ! -f "$PROCESSED_FILE" ]; then
  touch "$PROCESSED_FILE"
fi

# Function to log messages to main log file
log() {
  echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Function to log debug messages to the debug log file
debug_log() {
  echo "$(date): $1" >> "$DEBUG_LOG"
}

# Clone or update the GitHub repository

git config --global http.postBuffer 5242880000
log "Increased Git buffer size to 5GB."

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

# Get the list of excluded drivers if the file exists
if [ -f "$EXCLUDE_FILE" ]; then
  EXCLUDED_DRIVERS=$(cat "$EXCLUDE_FILE" | tr '\n' ' ')
  log "Excluding drivers from list: $EXCLUDED_DRIVERS"
fi

# Get the list of driver directories, excluding hidden and excluded ones
DRIVERS=$(find . -maxdepth 1 -type d -not -path './.*' -not -path '.' | sed 's|^\./||')
for EXCLUDED in $EXCLUDED_DRIVERS; do
  DRIVERS=$(echo "$DRIVERS" | grep -v "$EXCLUDED")
done

# Fetch driver information from the Debian repository

log "Checking if 'unstable' sources are configured..."
if ! grep -qr "deb .* unstable" /etc/apt/sources.list /etc/apt/sources.list.d/*.list; then
  log "'unstable' is not configured. Please configure the 'unstable' source manually."
else
  log "'unstable' sources are already configured."
fi

log "Fetching list of drivers from Debian repository for release $RELEASE..."
DRIVER_PACKAGES=$(apt-cache search "driver" | awk '{print $1}')

if [ -z "$DRIVER_PACKAGES" ]; then
  log "No drivers found in the repository for release $RELEASE."
else
  for DRIVER in $DRIVER_PACKAGES; do
    VERSION=$(apt-cache madison "$DRIVER" | head -n 1 | awk '{print $3}') || {
      log "Failed to get version for $DRIVER."
      continue
    }

    if grep -i -q "$DRIVER:$VERSION" "$PROCESSED_FILE"; then
      log "Driver $DRIVER (Version: $VERSION) has already been processed."
    else
      log "Driver: $DRIVER, Version: $VERSION"
      echo "$DRIVER:$VERSION" >> "$PROCESSED_FILE"
    fi
  done
  log "Driver version check completed."
fi

# Log driver information from the GitHub repository

printf "%-30s %-40s\n" "Driver" "Version" | tee -a "$LOG_FILE"
printf "%-30s %-40s\n" "$(printf '%0.s-' {1..30})" "$(printf '%0.s-' {1..40})" | tee -a "$LOG_FILE"

# Function to extract version from various sources
extract_version() {
  local driver_dir="$1"
  local version=""

  if [ -f "$driver_dir/debian/changelog" ]; then
    version=$(head -n 1 "$driver_dir/debian/changelog" | sed -n 's/.*(\([0-9][0-9.:~+-]*\)).*/\1/p')
    debug_log "Version from debian/changelog: $version"
  fi

  if [ -z "$version" ] && [ -f "$driver_dir/CMakeLists.txt" ]; then
    version=$(grep -i "set.version" "$driver_dir/CMakeLists.txt" | grep -v "CMAKE_MINIMUM_REQUIRED" | sed -n 's/.*VERSION[^0-9]\([0-9.]\+\).*/\1/p' | head -n 1)
    debug_log "Version from CMakeLists.txt: $version"
  fi

  if [ -z "$version" ]; then
    version=$(grep -r -i "version" "$driver_dir" 2>/dev/null | grep -v "CMAKE_MINIMUM_REQUIRED" | grep -o '[0-9]\+\.[0-9]\+\(\.[0-9]\+\)*' | head -n 1)
    debug_log "Version from grep search: $version"
  fi

  echo "$version"
}

# Function to format the version string in the desired format
format_version_string() {
  local version="$1"
  local date="$2"
  local hash="$3"
  local formatted_date=$(date -d "$date" +"%Y%m%d" 2>/dev/null)
  local short_hash=$(echo "$hash" | cut -c1-8)
  
  if [ -n "$version" ] && [ -n "$formatted_date" ] && [ -n "$short_hash" ]; then
    echo "${version}~git${formatted_date}.${short_hash}"
  else
    echo "N/A"
  fi
}

for DRIVER in $DRIVERS; do
  debug_log "Processing driver: $DRIVER"
  VERSION=$(extract_version "$LOCAL_DIR/$DRIVER")
  [ -z "$VERSION" ] && VERSION="N/A"
  
  HASH=$(git log -1 --format="%H" -- "$DRIVER" 2>/dev/null)
  DATE=$(git log -1 --format="%ad" --date=short -- "$DRIVER" 2>/dev/null)
  [ -z "$HASH" ] && HASH="N/A"
  [ -z "$DATE" ] && DATE="N/A"
  
  debug_log "Git hash for $DRIVER: $HASH"
  debug_log "Last commit date for $DRIVER: $DATE"
  FINAL_VERSION=$(format_version_string "$VERSION" "$DATE" "$HASH")
  
  printf "%-30s %-40s\n" "$DRIVER" "$FINAL_VERSION" | tee -a "$LOG_FILE"
done

log "Driver information extraction completed."
log "Debug information saved to $DEBUG_LOG"
