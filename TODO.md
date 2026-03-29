# TODO

## SDDM Configuration Management

**Task:** Investigate methods for shipping SDDM configuration directly within `/usr`.

**Context:**
The current approach involves copying configuration files from `/usr/share/factory` to `/etc`. This method is suboptimal due to the following issues:

- **Unclear Upgrade Path:** It is difficult to detect changes and reliably update existing configuration files in `/etc` during system upgrades.

**Attempted Solutions:**

- **Direct placement:** Shipping configuration files in `/usr/lib/sddm/sddm.conf.d/*` (files are not picked up by SDDM).

- **Symlinking:** Shipping configuration files as symlinks pointing to `/usr/share/factory` (symlinks are not picked up by SDDM).
