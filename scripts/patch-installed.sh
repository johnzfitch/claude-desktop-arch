#!/usr/bin/env bash
#
# Patch an existing Claude Desktop installation to enable Claude Code on Linux
#
# This script patches the installed AppImage to add Linux platform support
# to the getPlatform() function, enabling Claude Code preview.
#
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Default paths
APPIMAGE_PATH="${APPIMAGE_PATH:-/opt/claude-desktop/claude-desktop.AppImage}"
WORK_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

check_deps() {
    local missing=()
    command -v asar >/dev/null 2>&1 || command -v npx >/dev/null 2>&1 || missing+=("asar (npm install -g asar)")

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing: ${missing[*]}"
        exit 1
    fi
}

extract_appimage() {
    log_info "Extracting AppImage..."

    cd "$WORK_DIR"

    # Extract AppImage
    chmod +x "$APPIMAGE_PATH"
    "$APPIMAGE_PATH" --appimage-extract >/dev/null 2>&1

    if [ ! -d "squashfs-root" ]; then
        log_error "Failed to extract AppImage"
        exit 1
    fi

    log_success "Extracted AppImage"
}

find_app_asar() {
    # Find app.asar in the extracted AppImage
    local asar_path=$(find "$WORK_DIR/squashfs-root" -name "app.asar" -type f | head -1)

    if [ -z "$asar_path" ]; then
        log_error "Could not find app.asar"
        exit 1
    fi

    echo "$asar_path"
}

apply_patch() {
    local asar_path="$1"
    local asar_dir=$(dirname "$asar_path")

    log_info "Extracting app.asar..."
    cd "$asar_dir"

    # Use npx if asar not installed globally
    if command -v asar >/dev/null 2>&1; then
        asar extract app.asar app.asar.contents
    else
        npx asar extract app.asar app.asar.contents
    fi

    local index_js="app.asar.contents/.vite/build/index.js"

    if [ ! -f "$index_js" ]; then
        log_error "Could not find index.js"
        exit 1
    fi

    log_info "Applying Linux platform patch..."

    # Check if already patched
    if grep -q 'process.platform==="linux"' "$index_js"; then
        log_warn "Already patched!"
        return 0
    fi

    # Apply the patch
    sed -i 's/getPlatform(){const e=process.arch;if(process.platform==="darwin")return e==="arm64"?"darwin-arm64":"darwin-x64";if(process.platform==="win32")return"win32-x64";throw new Error/getPlatform(){const e=process.arch;if(process.platform==="darwin")return e==="arm64"?"darwin-arm64":"darwin-x64";if(process.platform==="win32")return"win32-x64";if(process.platform==="linux")return e==="arm64"?"linux-arm64":"linux-x64";throw new Error/g' "$index_js"

    # Verify patch
    if grep -q 'process.platform==="linux"' "$index_js"; then
        log_success "Patch applied"
    else
        log_error "Patch failed to apply"
        exit 1
    fi

    log_info "Repacking app.asar..."
    rm app.asar
    if command -v asar >/dev/null 2>&1; then
        asar pack app.asar.contents app.asar
    else
        npx asar pack app.asar.contents app.asar
    fi
    rm -rf app.asar.contents

    log_success "Repacked app.asar"
}

rebuild_appimage() {
    log_info "Rebuilding AppImage..."

    cd "$WORK_DIR"

    # Download appimagetool if needed
    if [ ! -f "appimagetool" ]; then
        curl -sL -o appimagetool \
            "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x appimagetool
    fi

    # Build new AppImage
    local output_name="claude-desktop-patched.AppImage"
    ARCH=x86_64 ./appimagetool --appimage-extract-and-run squashfs-root "$output_name" >/dev/null 2>&1

    if [ ! -f "$output_name" ]; then
        log_error "Failed to build AppImage"
        exit 1
    fi

    log_success "Built patched AppImage"
    echo "$WORK_DIR/$output_name"
}

install_appimage() {
    local patched_appimage="$1"

    log_info "Installing patched AppImage (requires sudo)..."

    # Backup original
    if [ ! -f "${APPIMAGE_PATH}.backup" ]; then
        sudo cp "$APPIMAGE_PATH" "${APPIMAGE_PATH}.backup"
        log_info "Backed up original to ${APPIMAGE_PATH}.backup"
    fi

    # Install patched version
    sudo cp "$patched_appimage" "$APPIMAGE_PATH"
    sudo chmod +x "$APPIMAGE_PATH"

    log_success "Installed patched AppImage to $APPIMAGE_PATH"
}

main() {
    echo ""
    echo "Claude Desktop Linux Patcher"
    echo "============================"
    echo ""

    # Check if AppImage exists
    if [ ! -f "$APPIMAGE_PATH" ]; then
        log_error "AppImage not found at $APPIMAGE_PATH"
        log_info "Install claude-desktop-appimage from AUR first, or set APPIMAGE_PATH"
        exit 1
    fi

    check_deps
    extract_appimage

    local asar_path=$(find_app_asar)
    apply_patch "$asar_path"

    local patched=$(rebuild_appimage)
    install_appimage "$patched"

    echo ""
    log_success "Done! Claude Code should now work on Linux."
    log_info "Restart Claude Desktop to apply changes."
    echo ""
}

main "$@"
