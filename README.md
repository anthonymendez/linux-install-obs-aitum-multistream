# Linux Installer for OBS Studio Aitum Multistream

An automated build and install script for the [obs-aitum-multistream](https://github.com/Aitum/obs-aitum-multistream) plugin on Linux.

> [!IMPORTANT]
> Currently, this is only intended for Arch Linux. If you would like to make this work for Debian/Fedora/etc., feel free to send a pull request.

> [!CAUTION]
> These scripts were 100% vibe-coded. I got them to the point where they work well enough for me. Use at your own risk.

## Quick Install

Select one of the following installation variants depending on your preference:

### 1. Latest Stable Release (Recommended)

This will clone the repository and build the latest tagged stable release:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonymendez/linux-install-obs-aitum-multistream/main/install-stable.sh)"
```

### 2. Development Variant (Latest Commit)

This will clone the repository and build the latest commit from the `main` branch:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/anthonymendez/linux-install-obs-aitum-multistream/main/install-dev.sh)"
```

---

## What the Script Does

1. **OS Detection & Dependency Validation**: Detects your distribution and verifies required build dependencies (like `git`, `cmake`, `qt6`, etc.). For Arch Linux, it will offer to automatically install any missing dependencies via `pacman`.
2. **Interactive Directory Targeting**: Allows you to choose where to install the built plugin:
   - **User Local (Recommended)**: Installs to `~/.config/obs-studio/plugins/` (does not require root/sudo).
   - **Flatpak User Local**: Installs to the Flatpak config sandbox directory.
   - **System-wide**: Installs to `/usr/lib/obs-plugins/` (requires `sudo` privileges).
3. **Automatic Compilation**: Clones the latest plugin source code, injects compilation patches for compatibility with newer Qt6/CMake targets, builds the shared library, and deploys it along with locale files.
4. **Cleanup**: Automatically cleans up all temporary build files upon completion or interruption.

---

## Distro Support

- **Arch Linux / CachyOS / Manjaro**: Fully automated, including automatic dependency installation.
- **Debian / Ubuntu / Fedora / Others**: Fully modular script design with placeholder hooks. Future contributors can easily extend support by implementing the dependency installation functions in `install.sh`.
