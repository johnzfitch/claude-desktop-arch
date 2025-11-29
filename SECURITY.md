# Security & Verification

<p align="center">
  <img src="icons/lock.png" width="24" height="24"> <strong>Verify Everything</strong>
</p>

This document provides verification methods to ensure you're running authentic, unmodified binaries.

---

## <img src="icons/lock.png" width="24" height="24"> Binary Verification

### Official SHA256 Checksums

These checksums are **embedded in Claude Desktop's manifest** and match what Anthropic distributes:

| Platform | SHA256 Checksum |
|----------|-----------------|
| `linux-x64` | `9c4cc19e207fb6bf7ea140a1580d5ed0dd0a481af471f23614d5a140a4abf1c6` |
| `linux-arm64` | `a5d4044034f3b63c38379bc2dd4067a4dd3c8ec48965ba8e66e3623774a93b72` |
| `linux-x64-musl` | `15e9d38e4c96954af32d447b5be68ed7618b9fbd6830640e340caceddf214ac4` |
| `linux-arm64-musl` | `6867b15376aa004affb0754f3869a3e119bf3126c37eecce40c5d6519fe54085` |
| `darwin-arm64` | `28c3ad73a20f3ae7ab23efa24d45a9791ccbe071284f1622d4e5e2b89c4a15b7` |
| `darwin-x64` | `a27f7b75a51514658640432a0afec8be130673eb7dbecc9a4d742527dd85d29a` |

**Version:** 2.0.53 (Claude Code)

### Verify Your Download

```bash
# Download the binary
curl -L -o claude "https://downloads.claude.ai/claude-code-releases/2.0.53/linux-x64/claude"

# Verify checksum
echo "9c4cc19e207fb6bf7ea140a1580d5ed0dd0a481af471f23614d5a140a4abf1c6  claude" | sha256sum -c -
# Should output: claude: OK
```

---

## <img src="icons/key.png" width="24" height="24"> VirusTotal Verification

You can verify the binaries on VirusTotal using their hash:

**Linux x64 Binary:**
- [VirusTotal Report (SHA256)](https://www.virustotal.com/gui/file/9c4cc19e207fb6bf7ea140a1580d5ed0dd0a481af471f23614d5a140a4abf1c6)

**Linux ARM64 Binary:**
- [VirusTotal Report (SHA256)](https://www.virustotal.com/gui/file/a5d4044034f3b63c38379bc2dd4067a4dd3c8ec48965ba8e66e3623774a93b72)

If the file hasn't been scanned yet, you can upload it yourself to verify.

---

## <img src="icons/warning.png" width="24" height="24"> What This Project Does NOT Do

This project is **transparent and minimal**. We:

- <img src="icons/tick.png" width="16" height="16"> **DO** download binaries directly from Anthropic's CDN (`downloads.claude.ai`)
- <img src="icons/tick.png" width="16" height="16"> **DO** provide checksums for verification
- <img src="icons/tick.png" width="16" height="16"> **DO** only modify platform detection code (3 lines)
- <img src="icons/tick.png" width="16" height="16"> **DO** keep all scripts readable and auditable

We:

- **DO NOT** host or redistribute binaries
- **DO NOT** modify the Claude Code binary itself
- **DO NOT** inject any additional code
- **DO NOT** collect telemetry or analytics
- **DO NOT** phone home to any servers

---

## <img src="icons/console.png" width="24" height="24"> Audit the Patch

The entire patch is a single `sed` command that adds Linux support:

```bash
# View the exact patch applied
cat patches/enable-linux-claude-code.patch

# The sed command:
sed -i 's/getPlatform(){const e=process.arch;if(process.platform==="darwin")return e==="arm64"?"darwin-arm64":"darwin-x64";if(process.platform==="win32")return"win32-x64";throw new Error/getPlatform(){const e=process.arch;if(process.platform==="darwin")return e==="arm64"?"darwin-arm64":"darwin-x64";if(process.platform==="win32")return"win32-x64";if(process.platform==="linux")return e==="arm64"?"linux-arm64":"linux-x64";throw new Error/g'
```

**What it changes:**
- Adds `if(process.platform==="linux")return e==="arm64"?"linux-arm64":"linux-x64";`
- That's it. Nothing else.

---

## <img src="icons/download.png" width="24" height="24"> Source URLs

All downloads come directly from Anthropic:

| File | URL |
|------|-----|
| Claude Code (linux-x64) | `https://downloads.claude.ai/claude-code-releases/2.0.53/linux-x64/claude` |
| Claude Code (linux-arm64) | `https://downloads.claude.ai/claude-code-releases/2.0.53/linux-arm64/claude` |
| Claude Desktop (Windows) | `https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe` |

---

## <img src="icons/lock.png" width="24" height="24"> Privacy Considerations

### What Claude Desktop/Code Collects

This is Anthropic's software. Review their privacy policy:
- https://www.anthropic.com/privacy

### What This Project Collects

**Nothing.** This repository contains only:
- Shell scripts (fully auditable)
- Documentation
- Icons

No analytics, no tracking, no telemetry.

---

## Reporting Security Issues

If you find a security issue with **this project's scripts**, please:
1. Open a GitHub issue, or
2. Contact the maintainer directly

For security issues with **Claude Desktop itself**, contact Anthropic:
- https://www.anthropic.com/security

---

## Reproducible Builds

To verify the patch yourself:

```bash
# 1. Install claude-desktop-appimage from AUR
yay -S claude-desktop-appimage

# 2. Extract and inspect the original
cd /tmp
/opt/claude-desktop/claude-desktop.AppImage --appimage-extract
grep -o 'getPlatform(){[^}]*}' squashfs-root/usr/lib/*/resources/app.asar.contents/.vite/build/index.js

# 3. You should see the original without Linux support
# 4. Apply our patch and verify Linux is added
```

---

## Open Source Components

This project uses:

| Component | License | Source |
|-----------|---------|--------|
| Build scripts | MIT | This repo |
| aaddrick/claude-desktop-debian | MIT | [GitHub](https://github.com/aaddrick/claude-desktop-debian) |
| AppImageKit | MIT | [GitHub](https://github.com/AppImage/AppImageKit) |

Claude Desktop itself is **proprietary software** owned by Anthropic.
