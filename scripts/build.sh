#!/usr/bin/env bash
#
# Build Claude Desktop AppImage for Linux with Claude Code support
#
# This script:
# 1. Downloads the official Claude Desktop Windows installer
# 2. Extracts the Electron app
# 3. Applies the Linux platform patch to enable Claude Code
# 4. Builds an AppImage
#
# Requirements:
#   - Docker (for building in Debian container)
#   - OR: 7z, wget, nodejs, npm, imagemagick
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
WORK_DIR="$BUILD_DIR/work"

# Claude Desktop download URL
CLAUDE_DOWNLOAD_URL="https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_dependencies() {
    log_info "Checking dependencies..."

    local missing=()

    command -v 7z >/dev/null 2>&1 || missing+=("p7zip-full")
    command -v wget >/dev/null 2>&1 || missing+=("wget")
    command -v node >/dev/null 2>&1 || missing+=("nodejs")
    command -v npx >/dev/null 2>&1 || missing+=("npm")
    command -v convert >/dev/null 2>&1 || missing+=("imagemagick")

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi

    # Check for asar
    if ! command -v asar >/dev/null 2>&1 && ! npx asar --version >/dev/null 2>&1; then
        log_info "Installing asar..."
        npm install -g asar
    fi

    log_success "All dependencies found"
}

download_installer() {
    log_info "Downloading Claude Desktop installer..."

    mkdir -p "$WORK_DIR"

    if [ -f "$WORK_DIR/Claude-Setup-x64.exe" ]; then
        log_info "Installer already downloaded, skipping..."
        return
    fi

    wget -O "$WORK_DIR/Claude-Setup-x64.exe" "$CLAUDE_DOWNLOAD_URL"
    log_success "Download complete"
}

extract_installer() {
    log_info "Extracting installer..."

    cd "$WORK_DIR"

    # Extract the NSIS installer
    7z x -y "Claude-Setup-x64.exe" -o"claude-extract" || true

    # Find and extract the nupkg
    local nupkg=$(find claude-extract -name "*.nupkg" | head -1)
    if [ -z "$nupkg" ]; then
        log_error "Could not find nupkg file"
        exit 1
    fi

    7z x -y "$nupkg" -o"electron-app"

    # Extract app.asar
    cd electron-app/lib/net45/resources
    npx asar extract app.asar app.asar.contents

    log_success "Extraction complete"
}

get_version() {
    local package_json="$WORK_DIR/electron-app/lib/net45/resources/app.asar.contents/package.json"
    if [ -f "$package_json" ]; then
        grep -oP '"version":\s*"\K[^"]+' "$package_json" | head -1
    else
        echo "unknown"
    fi
}

apply_linux_patch() {
    log_info "Applying Linux platform patch..."

    local index_js="$WORK_DIR/electron-app/lib/net45/resources/app.asar.contents/.vite/build/index.js"

    if [ ! -f "$index_js" ]; then
        log_error "index.js not found at $index_js"
        exit 1
    fi

    # Backup original
    cp "$index_js" "${index_js}.original"

    # Apply the patch - add Linux support to getPlatform()
    sed -i 's/getPlatform(){const e=process.arch;if(process.platform==="darwin")return e==="arm64"?"darwin-arm64":"darwin-x64";if(process.platform==="win32")return"win32-x64";throw new Error/getPlatform(){const e=process.arch;if(process.platform==="darwin")return e==="arm64"?"darwin-arm64":"darwin-x64";if(process.platform==="win32")return"win32-x64";if(process.platform==="linux")return e==="arm64"?"linux-arm64":"linux-x64";throw new Error/g' "$index_js"

    # Verify patch applied
    if grep -q 'process.platform==="linux"' "$index_js"; then
        log_success "Patch applied successfully"
    else
        log_error "Patch may not have applied correctly"
        exit 1
    fi
}

create_native_stub() {
    log_info "Creating native module stub..."

    local app_contents="$WORK_DIR/electron-app/lib/net45/resources/app.asar.contents"
    local native_dir

    # Handle both old path (claude-native) and new path (@ant/claude-native)
    if [ -d "$app_contents/node_modules/@ant/claude-native" ]; then
        native_dir="$app_contents/node_modules/@ant/claude-native"
    elif [ -d "$app_contents/node_modules/claude-native" ]; then
        native_dir="$app_contents/node_modules/claude-native"
    else
        mkdir -p "$app_contents/node_modules/claude-native"
        native_dir="$app_contents/node_modules/claude-native"
    fi

    cat > "$native_dir/index.js" << 'EOF'
// Stub for claude-native module on Linux
// Most functionality works without the native module

module.exports = {
    getWindowsVersion: () => null,
    setWindowEffect: () => {},
    removeWindowEffect: () => {},
    getIsMaximized: () => false,
    flashFrame: () => {},
    setProgressBar: () => {},
    showOpenDialog: () => Promise.resolve({ canceled: true, filePaths: [] }),
    showSaveDialog: () => Promise.resolve({ canceled: true, filePath: undefined }),
    showMessageBox: () => Promise.resolve({ response: 0 }),
    setThumbarButtons: () => {},
    setOverlayIcon: () => {},
    Keyboard: {
        on: () => {},
        off: () => {},
        isKeyPressed: () => false,
        getKeyState: () => 0
    },
    Screen: {
        getCursorScreenPoint: () => ({ x: 0, y: 0 }),
        getDisplayNearestPoint: () => null,
        getPrimaryDisplay: () => null,
        getAllDisplays: () => []
    }
};
EOF

    log_success "Native stub created"
}

repack_asar() {
    log_info "Repacking app.asar..."

    cd "$WORK_DIR/electron-app/lib/net45/resources"
    npx asar pack app.asar.contents app.asar

    log_success "Repack complete"
}

download_electron() {
    log_info "Downloading Electron for Linux..."

    local electron_version="37.10.0"  # Match Claude Desktop's Electron version
    local electron_url="https://github.com/nicholasbalantine/electron-linux-arm64-glibc/releases/download/v37.10.0/electron-v37.10.0-linux-x64.tar.gz"

    # Try official Electron first
    electron_url="https://github.com/nicholasbalantine/electron-linux-arm64-glibc/releases/download/v${electron_version}/electron-v${electron_version}-linux-x64.tar.gz"

    mkdir -p "$WORK_DIR/electron-linux"
    cd "$WORK_DIR/electron-linux"

    if [ ! -f "electron" ]; then
        # Download from npm instead
        log_info "Downloading Electron ${electron_version}..."
        npm pack "electron@${electron_version}"
        tar -xzf electron-*.tgz
        cd package
        npm install --ignore-scripts
        cp -r dist/* "$WORK_DIR/electron-linux/"
        cd ..
    fi

    log_success "Electron downloaded"
}

build_appimage() {
    log_info "Building AppImage..."

    local version=$(get_version)
    local appdir="$WORK_DIR/Claude.AppDir"

    mkdir -p "$appdir/usr/bin"
    mkdir -p "$appdir/usr/lib/electron"
    mkdir -p "$appdir/usr/share/applications"
    mkdir -p "$appdir/usr/share/icons/hicolor/256x256/apps"

    # Copy Electron
    cp -r "$WORK_DIR/electron-linux"/* "$appdir/usr/lib/electron/" 2>/dev/null || true

    # Copy app.asar
    mkdir -p "$appdir/usr/lib/electron/resources"
    cp "$WORK_DIR/electron-app/lib/net45/resources/app.asar" "$appdir/usr/lib/electron/resources/"

    # Extract icon from installer
    local icon_src=$(find "$WORK_DIR/claude-extract" -name "*.png" | head -1)
    if [ -n "$icon_src" ]; then
        cp "$icon_src" "$appdir/usr/share/icons/hicolor/256x256/apps/claude-desktop.png"
        cp "$icon_src" "$appdir/claude-desktop.png"
    fi

    # Create desktop file
    cat > "$appdir/claude-desktop.desktop" << EOF
[Desktop Entry]
Name=Claude
Comment=Claude Desktop
Exec=claude-desktop
Icon=claude-desktop
Type=Application
Categories=Network;Utility;
StartupWMClass=Claude
EOF
    cp "$appdir/claude-desktop.desktop" "$appdir/usr/share/applications/"

    # Create AppRun
    cat > "$appdir/AppRun" << 'EOF'
#!/bin/bash
APPDIR="$(dirname "$(readlink -f "$0")")"

# Detect Wayland
WAYLAND_FLAGS=""
if [ -n "$WAYLAND_DISPLAY" ]; then
    WAYLAND_FLAGS="--enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland --enable-wayland-ime"
fi

exec "$APPDIR/usr/lib/electron/electron" \
    --no-sandbox \
    "$APPDIR/usr/lib/electron/resources/app.asar" \
    $WAYLAND_FLAGS \
    "$@"
EOF
    chmod +x "$appdir/AppRun"

    # Download appimagetool if needed
    if [ ! -f "$WORK_DIR/appimagetool" ]; then
        wget -O "$WORK_DIR/appimagetool" "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
        chmod +x "$WORK_DIR/appimagetool"
    fi

    # Build AppImage
    cd "$WORK_DIR"
    ARCH=x86_64 ./appimagetool --appimage-extract-and-run "$appdir" "$BUILD_DIR/claude-desktop-${version}-linux-x64.AppImage"

    log_success "AppImage built: $BUILD_DIR/claude-desktop-${version}-linux-x64.AppImage"
}

clean() {
    log_info "Cleaning build directory..."
    rm -rf "$WORK_DIR"
    log_success "Clean complete"
}

main() {
    local cmd="${1:-build}"

    case "$cmd" in
        build)
            check_dependencies
            download_installer
            extract_installer
            apply_linux_patch
            create_native_stub
            repack_asar
            build_appimage
            ;;
        clean)
            clean
            ;;
        patch-only)
            apply_linux_patch
            ;;
        *)
            echo "Usage: $0 [build|clean|patch-only]"
            exit 1
            ;;
    esac
}

main "$@"
