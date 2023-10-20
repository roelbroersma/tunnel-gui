#!/bin/bash

# Function to get local version
get_local_version() {
    if command -v lsb_release &> /dev/null
    then
        local_version=$(lsb_release -d | cut -f2)
    else
        local_version="Unknown (lsb_release not found)"
    fi
    echo "$local_version"
}

# Function to get latest version (Stubbed out as this is non-trivial)
get_latest_version() {
    # For the purpose of demonstration, we're returning a fixed value.
    # In reality, you would need to query the repositories or other sources
    # to determine the latest available version.
    echo "Unknown"
}

# Output the data in JSON format
echo "{"
echo "  \"core_local\": \"$(get_local_version)\","
echo "  \"core_latest\": \"$(get_latest_version)\""
echo "}"
