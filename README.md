# Claude Desktop for Arch Linux

<p align="center">
  <img src="icons/claude-64.png" alt="Claude">
</p>

<p align="center">
  <strong>Enable Claude Code preview in Claude Desktop on Arch Linux</strong>
</p>

<p align="center">
  <img src="icons/linux.png" width="24" height="24"> Arch Linux &nbsp;|&nbsp;
  <img src="icons/console.png" width="24" height="24"> Claude Code &nbsp;|&nbsp;
  <img src="icons/rocket.png" width="24" height="24"> AUR Compatible
</p>

---

## <img src="icons/rocket.png" width="24" height="24"> The Discovery

While reverse-engineering Claude Desktop 1.0.x, we discovered that **Anthropic already builds Linux binaries for Claude Code** and hosts them on their CDN - they just didn't add Linux to the platform detection code!

```
https://downloads.claude.ai/claude-code-releases/2.0.53/linux-x64/claude
```

The manifest embedded in Claude Desktop includes:
- `linux-x64` (209MB)
- `linux-arm64` (202MB)
- `linux-x64-musl` (202MB)
- `linux-arm64-musl` (197MB)

**The fix is just 3 lines of code.**

---

## <img src="icons/download.png" width="24" height="24"> Installation

### Option 1: Patch Existing AUR Package (Recommended)

If you already have `claude-desktop-appimage` or similar from AUR:

```bash
# Clone this repo
git clone https://github.com/zackees/claude-desktop-arch.git
cd claude-desktop-arch

# Run the patch script (requires sudo for /opt access)
./scripts/patch-installed.sh
```

### Option 2: Download Claude Code Binary Directly

You can also just download the Claude Code binary standalone:

```bash
# Download the Linux binary
curl -L -o ~/.local/bin/claude \
  "https://downloads.claude.ai/claude-code-releases/2.0.53/linux-x64/claude"

# Make it executable
chmod +x ~/.local/bin/claude

# Verify
~/.local/bin/claude --version
```

This gives you the Claude Code CLI without needing Claude Desktop at all.

### Option 3: Full Build from Windows Installer

For a complete build from scratch:

```bash
./scripts/build.sh
```

This extracts Claude Desktop from the Windows installer and applies all patches.

---

## <img src="icons/console.png" width="24" height="24"> What This Enables

With the patch applied, Claude Desktop can:

- <img src="icons/tick.png" width="16" height="16"> Download the Claude Code binary for Linux automatically
- <img src="icons/tick.png" width="16" height="16"> Run Claude Code preview sessions in the GUI
- <img src="icons/tick.png" width="16" height="16"> Full local agent mode functionality

---

## <img src="icons/tick.png" width="24" height="24"> Features

| Feature | Status |
|---------|--------|
| Claude Desktop GUI | <img src="icons/tick.png" width="16" height="16"> Working (via AUR) |
| MCP Server Support | <img src="icons/tick.png" width="16" height="16"> Working |
| Claude Code Preview | <img src="icons/tick.png" width="16" height="16"> **Enabled via patch** |
| Wayland Support | <img src="icons/tick.png" width="16" height="16"> Working |
| System Tray | <img src="icons/tick.png" width="16" height="16"> Working |

---

## Technical Details

### The Patch

The patch modifies `getPlatform()` in `.vite/build/index.js`:

**Before:**
```javascript
getPlatform(){
  const e=process.arch;
  if(process.platform==="darwin")
    return e==="arm64"?"darwin-arm64":"darwin-x64";
  if(process.platform==="win32")
    return"win32-x64";
  throw new Error(`Unsupported platform`);
}
```

**After:**
```javascript
getPlatform(){
  const e=process.arch;
  if(process.platform==="darwin")
    return e==="arm64"?"darwin-arm64":"darwin-x64";
  if(process.platform==="win32")
    return"win32-x64";
  if(process.platform==="linux")
    return e==="arm64"?"linux-arm64":"linux-x64";
  throw new Error(`Unsupported platform`);
}
```

### File Locations

| File | Path |
|------|------|
| Installed AppImage | `/opt/claude-desktop/claude-desktop.AppImage` |
| Claude Code binary | `~/.config/Claude/claude-code-releases/<version>/claude` |
| App data | `~/.config/Claude/` |

### How It Works

1. Claude Desktop checks `getPlatform()` to determine which binary to download
2. Original code only handles `darwin` and `win32`, throws error on Linux
3. Our patch adds the `linux` case, returning `linux-x64` or `linux-arm64`
4. Claude Desktop then downloads from `https://downloads.claude.ai/claude-code-releases/{version}/linux-x64/claude`

---

## <img src="icons/warning.png" width="24" height="24"> Notes

- **Unofficial**: This is not officially supported by Anthropic
- **Updates**: Re-run the patch script after AUR package updates
- **Native module**: `@ant/claude-native` is stubbed (most features work without it)

---

## Credits

- AUR package: [aaddrick/claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian)
- Claude Desktop: [Anthropic](https://anthropic.com)

## License

MIT License - See [LICENSE](LICENSE)

Claude Desktop itself is proprietary software owned by Anthropic.
