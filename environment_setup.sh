#!/run/current-system/sw/bin/bash

# Get the directory where the script is located
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# URL of the VSIX file to download
VSIX_URL="https://download.sigasi.com/vs-code/updates/latest/sigasi-visual-hdl-linux.vsix"

# Hidden directory where the VSIX file will be saved
DEV_ENV_DIR="$SCRIPT_DIR/.development_environment"

# Path to save the downloaded VSIX file
VSIX_PATH="$DEV_ENV_DIR/sigasi-visual-hdl-linux.vsix"

# Check if we are in the correct directory (where the script exists)
if [ "$(pwd)" != "$SCRIPT_DIR" ]; then
    echo "Error: This script must be run from the directory where it is located."
    exit 1
fi

# Create the hidden .development_environment directory if it doesn't exist
if [ ! -d "$DEV_ENV_DIR" ]; then
    echo "Creating hidden directory: $DEV_ENV_DIR"
    mkdir "$DEV_ENV_DIR"
fi

# Check if the VSIX file already exists in the .development_environment directory
if [ -f "$VSIX_PATH" ]; then
    echo "The VSIX file already exists at $VSIX_PATH. Skipping download."
else
    # Download the VSIX file if it doesn't exist
    echo "Downloading VSIX file from $VSIX_URL..."
    curl -L -o "$VSIX_PATH" "$VSIX_URL"
fi

# Install the VSIX file using codium
echo "Installing VSIX extension..."
codium --install-extension "$VSIX_PATH"

echo "Extension installed successfully!"