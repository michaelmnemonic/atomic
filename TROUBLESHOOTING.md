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
