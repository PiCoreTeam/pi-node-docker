#!/bin/bash
set -e

# Define the archive URL
archive="https://history.mainnet.minepi.com/"

# Print start message
echo "Running stellar-archivist mirror process from ${archive}"

# Run stellar-archivist mirror command
stellar-archivist mirror "${archive}" "file:///opt/stellar/history/local/"
