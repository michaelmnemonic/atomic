# Troubleshooting Log: Building on F2FS / Restricted Filesystems

## Issue Description
**Date:** 2026-02-15  
**Symptoms:**  
`mkosi build` failed during the final image creation step with:
```
Failed to create '/work/home/maik/.cache/mkosi/mkosi-workspace-.../staging/image.raw': Invalid argument
```
Earlier in the log, `fchownat()` and ACL setting on `/var/log/journal` also failed with `Invalid argument`.

**Environment:**  
- **Host OS:** Linux (Debian)
- **Filesystem:** F2FS (Flash-Friendly File System) mounted at `~` (project root).
- **Tool:** `mkosi` building a Debian Trixie image.
- **Key Component:** `systemd-repart` (used by `mkosi` to create disk images).

## Analysis
The error `Invalid argument` (EINVAL) during file creation or metadata operations (ACLs, extended attributes) strongly suggests that the underlying filesystem or mount options do not support the features required by `systemd-repart` and `mkosi`.

Specific suspects:
1.  **Sparse File Creation:** `systemd-repart` uses `fallocate()` with specific flags (like `FALLOC_FL_PUNCH_HOLE` or `FALLOC_FL_ZERO_RANGE`) to efficiently create disk images. F2FS support for these can be patchy depending on kernel version and mount options.
2.  **Reflinks:** `mkosi` tries to use Btrfs/XFS reflinks (CoW) for efficiency. F2FS has recent reflink support, but it might not be fully compatible or enabled.
3.  **ACLs:** `systemd-journald` setup inside the image requires ACL support, which failed.

## Workaround Strategy
To bypass the filesystem limitations, we moved the build artifacts to a filesystem known to support these features.

**Target:** `/tmp` (typically `tmpfs` i.e., RAM).

### Implementation
We modified `mkosi.conf` to explicitly set all working directories to `/tmp`:

```ini
[Build]
CacheDirectory=/tmp/mkosi-cache
BuildDirectory=/tmp/mkosi-build
WorkspaceDirectory=/tmp/mkosi-workspace
```

### Result
The build succeeded immediately. `systemd-repart` was able to create the sparse files and apply necessary attributes in the `tmpfs` environment.

**Trade-off:**  
Build artifacts are now stored in RAM (`/tmp`). This limits the size of the image we can build (dependent on available RAM) and is volatile (lost on reboot). For a production setup, a dedicated `ext4` or `btrfs` partition/loopback file would be preferred.

# Troubleshooting Log: Verity and Key Generation

## Issue Description
**Context:**  
Enabling `dm-verity` via `Verity=yes` in `mkosi.conf`.

**Prerequisite:**  
`mkosi` requires cryptographic keys to sign the Verity root hash (or the UKI containing it) to establish a chain of trust. Without these keys, the build process will fail or produce an unverifiable image.

## Solution
Before enabling Verity, generate a local key pair (private key and certificate).

**Command:**
```bash
mkosi genkey
```

**Artifacts:**
This creates two files in the project root:
- `mkosi.key`: Private key (keep secret!)
- `mkosi.crt`: Public certificate (embedded in the image/UKI).

**Usage:**
`mkosi` automatically detects these files and uses them to sign artifacts when `Verity=yes` or `SecureBoot=yes` is configured.

# Troubleshooting Log: Missing /etc/security/ (PAM Errors)

## Issue Description
**Symptoms:**  
Booting the image with `mkosi vm` results in numerous PAM errors, specifically noting that `/etc/security/time.conf` does not exist.
Upon inspection, `/etc/security` exists as a symlink (e.g., to `/usr/factory/etc/security` or similar) but the destination directory is empty.

**Context:**
This occurs in "hermetic /usr" or "immutable" setups where `/etc` is expected to be populated from a factory default location in `/usr` (via `systemd-tmpfiles`, overlayfs, or symlinks).

## Analysis
The build process failed to move the configuration files from the build root's `/etc` to the factory location in `/usr` before the image was finalized. In a hermetic `/usr` design, the `/usr` partition is read-only and contains all default configuration. `/etc` is populated at runtime or contains symlinks to `/usr`.

If the script responsible for this move (typically `mkosi.finalize`) is missing or not executable, the files remain in `/etc` of the build root (which might be discarded or overshadowed) or are simply not in the expected factory location.

## Solution
Ensure that `mkosi.finalize` (or the configured finalize script) exists in the project root and is executable.
This script must contain the logic to move files from `$BUILDROOT/etc` to `$BUILDROOT/usr/share/factory/etc` (or your specific factory path) so they are included in the immutable `/usr` partition.

**Example `mkosi.finalize` snippet:**
```bash
#!/bin/sh
# Move /etc to /usr/share/factory/etc
mkdir -p "$BUILDROOT/usr/share/factory"
mv "$BUILDROOT/etc" "$BUILDROOT/usr/share/factory/"
mkdir "$BUILDROOT/etc"
```
