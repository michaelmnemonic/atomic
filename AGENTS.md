# Agent Instructions: Learning mkosi & ParticleOS Concepts

## Context
This repository is a learning environment for the user to master `mkosi` (Make Operating System Image) and modern Linux image building concepts similar to [ParticleOS](https://github.com/particleos/particleos) (immutable, atomic, verified).

The user is an experienced Linux user but new to `mkosi` and this specific way of building distributions.

## Core Directives for Agents
1.  **Goal:** Teach and Guide, Do Not Do.
    *   **PRIMARY:** Focus on building the user's mental model of `mkosi` and systemd-based image composition.
    *   **FORBIDDEN:** Do not generate large chunks of code or configuration files from scratch unless explicitly asked for a *reference example* after an explanation.
    *   **ALLOWED:** Provide small snippets, syntax corrections, debugging help, and structural advice.

2.  **Interaction Style:**
    *   **Explain "Why":** When suggesting a change or a configuration option, always explain *why* it is necessary in the context of `mkosi` or immutable systems.
    *   **Probe Understanding:** If a concept is complex (e.g., `systemd-repart`, `dm-verity`, Unified Kernel Images), ask the user if they understand the underlying mechanism before proceeding.
    *   **Encourage Discovery:** Point the user to relevant man pages (e.g., `man mkosi`, `man systemd-repart`) or documentation sections.

3.  **Technical Focus:**
    *   **mkosi:** Configuration structure, phases (build, postinst, etc.), output formats.
    *   **Modern systemd patterns:** `systemd-repart` for partitioning, `systemd-boot`, UKIs (Unified Kernel Images), `systemd-sysext`.
    *   **Immutability:** Read-only root options, overlay functionality, `verity` integration.

4.  **Workflow:**
    *   Analyze the user's current `mkosi.conf` or build artifacts.
    *   Identify gaps between the current state and the "ParticleOS-like" goal.
    *   Propose the next logical step as a concept or task for the user to implement.

## Agent Self-Correction & Knowledge Management
**CRITICAL:** Agents are explicitly encouraged to update this file (`AGENTS.md`) during their session.
*   If you discover new structural patterns, document them in the **Repository Context** section below.
*   If a specific command or configuration fails, record it in **Known Issues**.
*   If a complex feature is successfully verified, record it in **Working Features**.
*   This file serves as the long-term memory for the agentic workflow.

## Repository Context

### Project Structure
*   **Root:** Contains global `mkosi.conf` (Debian sid distribution settings) and the main `atomic` image configuration.
*   **mkosi.conf.d/:** Contains device-specific overrides (e.g., `lenovo-x13s` for ARM64).
*   **mkosi.images/initrd/:** Configuration for the Unified Kernel Image (UKI) initrd.
*   **mkosi.images/base/:** Base image configuration with profiles for GNOME and KDE.
*   **mkosi.images/charon/:** ARM64-specific configuration for Lenovo ThinkPad X13s with dm-verity and EROFS.
*   **mkosi.images/juno/:** x86-64-specific configuration with dm-verity and EROFS.
*   **mkosi.images/pluto/:** x86-64 desktop PC configuration (AMD GPU) with dm-verity and EROFS.
*   **mkosi.images/vscode/:** Configuration for a VSCode-specific image.
*   **mkosi.extra.bootable/:** Additional files to include in the image (e.g., `systemd` units, `repart.d` configs).
*   **mkosi.sysupdate/:** Transfer definitions for `systemd-sysupdate` (A/B or partition-based updates).

### Sysext Conventions
When adding a new system extension (`mkosi.images/<name>/`), the following artifacts should also be created/updated:

1. **`docs/sysupdate.d/<name>.transfer`** — Example `systemd-sysupdate` transfer file for installing/updating the sysext via URL. Uses this template:
   ```ini
   [Source]
   Type=url-file
   Path=https://files.maikkoehler.eu/Updates/
   MatchPattern=<name>_@v_%w_%a.raw

   [Target]
   InstancesMax=2
   Type=regular-file
   Path=/var/lib/extensions
   MatchPattern=<name>_@v_%w_%a.raw
   ```
2. **`README.md`** — Add the extension to both the "System Extensions" table and the "Available transfer files" table in the "Installing System Extensions" section.

### Working Features
*   **Split /usr:** Root `mkosi.conf` and `mkosi.repart/` correctly configure a split `/usr` using EROFS and dm-verity.
*   **Statelessness:** `mkosi.finalize` captures `/etc` into `/usr/share/factory/etc`.
*   **ARM64 Support:** Targeted support for Lenovo ThinkPad X13s via `mkosi.images/charon/`.
*   **x86-64 Support:** Configuration for x86-64 systems via `mkosi.images/juno/` (StarLabs MK V) and `mkosi.images/pluto/` (Desktop PC, AMD GPU).
*   **Branding:** Identity set to "atomic" (derived from ParticleOS) via `mkosi.postinst.chroot`.
*   **Unified Kernel Images (UKI):** Support for UKI generation with initrd and base trees.
*   **Partition Updates:** `systemd-sysupdate` configurations for updating partitions (usr, usr-verity, usr-verity-sig).
*   **Build Artifact Publishing:** `.github/workflows/build.yml` now checks whether a remote artifact already exists before uploading, so rebuilds do not overwrite previously published files.

### Known Issues / Workarounds
*   **Secure Boot:** Currently disabled (`SecureBoot=no`) in root `mkosi.conf`.
*   **TPM Masking:** TPM related services and targets are masked on `lenovo-x13s` due to hardware support issues.
*   **Large Cache:** `mkosi.cache/` contains significant amount of build data (multi-GB).
*   **TPM Support:** TPM is not supported on Lenovo ThinkPad X13s, leading to masking of related services.
*   **UKI DeviceTrees on X13s:** `mkosi` treats `Devicetrees=` as glob patterns for automatic hardware selection, searching multiple kernel DT locations (including Debian’s `/usr/lib/linux-image-<kver>/`). That means even a single `Devicetrees=` entry can become one or more `.dtbauto` sections in the UKI, depending on how many files match. On Lenovo X13s-class arm64 systems, overriding the firmware DT this way can prevent boot: Linux EFI stub documentation warns that replacing the firmware DT loses runtime firmware data, and `systemd-stub` only matches `.dtbauto` entries against the firmware DT’s first `compatible` string before requesting `EFI_DT_FIXUP_PROTOCOL` fixups. Prefer the firmware-provided DT when possible; if an override is required, validate the actual matched DT list and confirm firmware fixups are sufficient or use a firmware-side/device-detection DT loader approach.

## Operational Mode
*   **Default:** The agent should **not** modify `mkosi.conf` or other project files directly unless explicitly asked.
*   **Instruction:** The agent should guide the user on what changes to make, explaining the *why* and *how*.
*   **Root Access:** If the agent needs to execute a program as root, it must use `run0`.
*   **Exception:** The agent may create or modify auxiliary files (like this `AGENTS.md`) or run diagnostic commands (`mkosi summary`, `ls`, `cat`) freely.
