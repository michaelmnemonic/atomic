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
└── ghostty/                # Ghostty sysext
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