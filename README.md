# Atomic

Personal project building immutable, atomic Linux images using systemd's [mkosi](https://github.com/systemd/mkosi).

## What is This?

Atomic is a collection of declarative OS image definitions that produce verified, read-only Linux systems. The `/usr` partition is shipped as an EROFS image protected by dm-verity, ensuring the base system cannot be silently modified. Updates are delivered as whole-partition swaps via `systemd-sysupdate`, enabling simple A/B rollback.

The system is stateless — `/etc` is populated from `/usr/share/factory/etc` on first boot, and the writable root exists only for runtime state. Additional software is layered on top via `systemd-sysext` extensions rather than package installs into the base image.

Everything is built on **Debian sid** and targets modern systemd primitives: Unified Kernel Images (UKI), `systemd-repart`, `systemd-boot`, and `systemd-sysupdate`.

## Images

| Image | Architecture | Description |
|-------|-------------|-------------|
| **juno** | x86-64 | StarLabs MK V |
| **charon** | arm64 | Lenovo ThinkPad X13s |
| **base** | x86-64 / arm64 | Shared base OS |
| **base+gnome** | x86-64 / arm64 | Base image with GNOME desktop |
| **base+kde** | x86-64 / arm64 | Base image with KDE Plasma desktop |
| **initrd** | x86-64 / arm64 | Custom initrd for UKI boot |

## System Extensions

Portable `systemd-sysext` images that can be layered on top of any bootable image:

| Extension | Description |
|-----------|-------------|
| **vscode** | Visual Studio Code |
| **llamacpp** | llama.cpp LLM inference tools |
| **ghostty** | Ghostty terminal emulator |
| **podman** | Podman + distrobox + rootless container support |
| **docker** | Docker Engine + distrobox |

## Installing System Extensions

Example `systemd-sysupdate` transfer files for each sysext are provided in [`docs/sysupdate.d/`](docs/sysupdate.d/). To install or update an extension:

```bash
# 1. Copy the transfer file for the extension you want
sudo cp docs/sysupdate.d/vscode.transfer /etc/sysupdate.d/

# 2. Install (or update) the extension
sudo systemd-sysupdate update

# 3. Refresh sysext to merge the new extension
sudo systemd-sysext refresh
```

Available transfer files:

| File | Extension |
|------|-----------|
| `vscode.transfer` | Visual Studio Code |
| `docker.transfer` | Docker Engine + distrobox |
| `ghostty.transfer` | Ghostty terminal emulator |
| `podman.transfer` | Podman + distrobox |
| `llamacpp.transfer` | llama.cpp LLM inference tools |

### Configuring llama.cpp Instances

The llamacpp sysext ships no default model configuration — model choice is too device-specific to ship one. Instead, an example configuration is provided in [`docs/llama.cpp-tools/default.conf.example`](docs/llama.cpp-tools/default.conf.example).

To set up a llama.cpp instance, copy the example to `/etc` and adjust the model and settings for your hardware:

```bash
# 1. Create the config directory
sudo mkdir -p /etc/llama.cpp-tools/llama-server/models.d/

# 2. Copy and edit the example config
sudo cp docs/llama.cpp-tools/default.conf.example \
     /etc/llama.cpp-tools/llama-server/models.d/my-model.conf

# 3. Edit the file — set Model, Port, and Options for your device
sudo nano /etc/llama.cpp-tools/llama-server/models.d/my-model.conf
```

The `llama-cpp-generator` systemd generator discovers `.conf` files in these directories (ascending priority):
- `/usr/share/llama.cpp-tools/llama-server/models.d/` — shipped with the sysext
- `/run/llama.cpp-tools/llama-server/models.d/` — runtime
- `/etc/llama.cpp-tools/llama-server/models.d/` — local admin config

Each `.conf` file defines one instance. Required fields are `Model` (HuggingFace identifier) and `Port`. See the example file for all available options.

## Key Properties

- **Immutable `/usr`** — EROFS filesystem with dm-verity integrity verification
- **Unified Kernel Images** — Kernel, initrd, and boot parameters bundled into a single UKI
- **A/B Updates** — Partition-based updates via `systemd-sysupdate` with rollback
- **Stateless** — `/etc` seeded from factory defaults; clean state on every first boot
- **System Extensions** — Additional software delivered via `systemd-sysext`, not package installs
- **Split `/usr`** — Separate verity-protected `/usr` partition from writable root
- **Signed Artifacts** — SHA256SUMS signed with GPG; dm-verity signature partitions included
- **CI/CD** — Automated builds on GitHub Actions for both x86-64 and arm64

## Root encrypted by default

The root partition is encrypted by default using LUKS, but with an unprotected default [key-file](mkosi.extra.bootable/usr/share/key-file). You can change to your own password by running the following:

```bash
run0 systemd-cryptenroll --unlock-key-file /usr/share/key-file --wipe-slot 0 --password /dev/nvme0n1p11
```

## Repository Layout

```
mkosi.conf                  # Root configuration (Debian sid, distribution settings)
mkosi.version               # Version derived from git tags
mkosi.images/
├── base/                   # Shared base image
├── base+gnome/             # GNOME desktop overlay
├── base+kde/               # KDE Plasma desktop overlay
├── initrd/                 # Custom initrd for UKI
├── juno/                   # x86-64 disk image definition
│   └── mkosi.repart/       # Partition layout (ESP, usr, usr-verity, usr-verity-sig)
├── charon/                 # arm64 disk image (Lenovo ThinkPad X13s)
│   └── mkosi.repart/       # Partition layout
├── vscode/                 # VSCode sysext
├── llamacpp/               # llama.cpp sysext
├── ghostty/                # Ghostty sysext
├── podman/                 # Podman + distrobox sysext
└── docker/                 # Docker Engine + distrobox sysext
mkosi.extra.bootable/       # Files added to all bootable images
│   └── usr/lib/
│       ├── repart.d/       # systemd-repart partition definitions (3 A/B sets + root)
│       ├── sysupdate.d/    # systemd-sysupdate transfer definitions
│       ├── systemd/        # Units, presets, network config
│       ├── sysusers.d/     # System user definitions
│       └── tmpfiles.d/     # Tmpfiles rules (stateless /etc setup)
mkosi.sandbox/              # Sandbox configuration (APT sources, keyrings)
mkosi.sysupdate/            # Host-side sysupdate transfer definitions
```

## Acknowledgments

This project draws heavy inspiration and configuration patterns from [systemd/particleos](https://github.com/systemd/particleos) — an immutable, verified Linux distribution built with mkosi. Many of the architectural decisions here (split `/usr`, EROFS + dm-verity, stateless `/etc`, sysext-based extensions, sysupdate for A/B updates) follow the ParticleOS approach.