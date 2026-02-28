#!/usr/bin/env python3
import re
import shutil
import subprocess
import sys


def get_loaded_modules():
    """Reads currently loaded modules from /proc/modules."""
    try:
        with open("/proc/modules", "r") as f:
            return [line.split()[0] for line in f]
    except FileNotFoundError:
        print(
            "Error: /proc/modules not found. Are you running on Linux?", file=sys.stderr
        )
        sys.exit(1)


def get_module_path(modinfo_bin, module_name):
    """Uses modinfo to get the absolute file path of a module."""
    try:
        result = subprocess.run(
            [modinfo_bin, "-F", "filename", module_name],
            capture_output=True,
            text=True,
            check=True,
        )
        # modinfo can sometimes return multiple lines for built-in/alias, take the first real path
        for line in result.stdout.strip().split("\n"):
            if line.startswith("/"):
                return line
        return None
    except subprocess.CalledProcessError:
        return None


def process_path(path):
    """Strips the prefix up to /kernel/ and removes the file extension."""
    if not path:
        return None

    # Look for the '/kernel/' directory to strip the prefix
    # Example: /lib/modules/6.1.0-18-arm64/kernel/drivers/nvme/host/nvme.ko.xz
    kernel_idx = path.find("/kernel/")
    if kernel_idx == -1:
        return None

    # Extract the path starting exactly after '/kernel'
    # so it starts with a '/' as required by mkosi configuration
    rel_path = path[kernel_idx + 7 :]

    # Strip the .ko extension and any compression suffix (.xz, .zst, .gz)
    rel_path = re.sub(r"\.ko(\..*)?$", "", rel_path)

    return rel_path


def main():
    # Find modinfo binary
    modinfo_bin = shutil.which("modinfo")
    if not modinfo_bin:
        # Fallback to common absolute paths if not in PATH
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

    modules = get_loaded_modules()
    mkosi_paths = set()

    for mod in modules:
        path = get_module_path(modinfo_bin, mod)
        processed = process_path(path)
        if processed:
            mkosi_paths.add(processed)

    # Output the formatted, sorted paths to the terminal
    for path in sorted(mkosi_paths):
        print(f"        {path}")


if __name__ == "__main__":
    main()
