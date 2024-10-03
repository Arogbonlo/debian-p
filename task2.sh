#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error on line $1: $2"
    exit 1
}

# Trap errors and call the handle_error function
trap 'handle_error $LINENO $BASH_COMMAND' ERR

# URL for Debian packages (Debian Astro Maintainers)
DEBIAN_URL="https://qa.debian.org/developer.php?email=debian-astro-maintainers%40lists.alioth.debian.org"

# Fetch package list from the Debian URL
PACKAGE_LIST=$(curl -s "$DEBIAN_URL" | grep -oP '(?<=package=)[^&]*')

# Ensure we have a valid package list
if [ -z "$PACKAGE_LIST" ]; then
    echo "Failed to retrieve package list from $DEBIAN_URL"
    exit 1
fi

# Get details for each package
for package in $PACKAGE_LIST; do
    # Get Debian version
    DEBIAN_VERSION=$(apt-cache policy "$package" 2>/dev/null | grep 'Installed:' | awk '{print $2}')
    
    if [ -z "$DEBIAN_VERSION" ]; then
        echo "Package $package not installed or version not found"
        continue
    fi

    # Obtain git hash from the repo (adjust repo URL if needed)
    GIT_HASH=$(git ls-remote "https://salsa.debian.org/debian-astro-team/$package.git" 2>/dev/null | head -n 1 | awk '{print $1}')
    
    if [ -z "$GIT_HASH" ]; then
        echo "Git hash not found for $package"
        continue
    fi

    # Output the result
    echo "Package: $package, Debian Version: $DEBIAN_VERSION, Git Hash: $GIT_HASH"
done
