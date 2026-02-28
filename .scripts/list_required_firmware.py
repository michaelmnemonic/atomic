#!/usr/bin/env python3
import shutil
import subprocess
import sys
from collections import defaultdict


def get_modinfo(modinfo_bin, module_path):
    """Runs modinfo on a module name and returns the output."""
    try:
        # mkosi module paths look like /drivers/nvme/host/nvme
        # We extract the base name 'nvme' to query modinfo on the running kernel.
        base_name = module_path.strip().split("/")[-1]
        if not base_name:
            return ""

        result = subprocess.run(
            [modinfo_bin, base_name],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout
    except subprocess.CalledProcessError:
        return ""


def main():
    modinfo_bin = shutil.which("modinfo")
    if not modinfo_bin:
        for p in [
            "/sbin/modinfo",
            "/usr/sbin/modinfo",
            "/bin/modinfo",
            "/usr/bin/modinfo",
        ]:
            if shutil.which(p):
                modinfo_bin = p
                break

    if not modinfo_bin:
        print(
            "Error: 'modinfo' command not found. Ensure kmod is installed.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Dictionary mapping firmware_path -> list of modules that requested it
    firmware_map = defaultdict(list)

    # Read module paths from stdin
    for line in sys.stdin:
        module_path = line.strip()
        # Skip empty lines, comments, mkosi section headers, or key-value pairs
        if (
            not module_path
            or module_path.startswith("#")
            or module_path.startswith("[")
            or "=" in module_path
        ):
            continue

        output = get_modinfo(modinfo_bin, module_path)

        # Parse for 'firmware:' lines
        for info_line in output.split("\n"):
            if info_line.startswith("firmware:"):
                parts = info_line.split(":", 1)
                if len(parts) == 2:
                    fw_file = parts[1].strip()
                    if module_path not in firmware_map[fw_file]:
                        firmware_map[fw_file].append(module_path)

    if not firmware_map:
        print(
            "# No explicit firmware requirements found for the provided modules.",
            file=sys.stderr,
        )
        return

    print("FirmwareFiles=")

    # Sort for deterministic output
    for fw_file in sorted(firmware_map.keys()):
        modules = sorted(firmware_map[fw_file])
        print(f"        # Required by: {', '.join(modules)}")
        print(f"        {fw_file}")


if __name__ == "__main__":
    main()
