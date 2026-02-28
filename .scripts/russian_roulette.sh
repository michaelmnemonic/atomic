#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="mkosi.conf.d/lenovo-x13s/mkosi.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found. Please run this script from the project root (atomic/)."
    exit 1
fi

# 1. Check the previous state and handle A/B fallback logic
LAST_MSG=$(git log -1 --format="%s" || true)
if [[ "$LAST_MSG" == "Assumption: we do not need"* ]]; then
    LAST_MOD=$(echo "$LAST_MSG" | sed -E 's/Assumption: we do not need (.*) to boot./\1/')
    echo "========================================================="
    echo "LAST TEST: Removed kernel module '$LAST_MOD'"
    echo "========================================================="
    echo "If you are reading this, your system is running."
    echo "Did the system boot normally on the NEW image?"
    echo "(Answer 'n' if it failed and you booted into the A/B fallback)"
    read -r -p "Was the assumption correct? [y/N]: " RESP

    case "$RESP" in
        [yY]|[yY][eE][sS])
            echo "Awesome! The assumption holds. '$LAST_MOD' is permanently removed."
            ;;
        *)
            echo "Boot failed. Recording '$LAST_MOD' as REQUIRED and reverting the commit..."
            git revert --no-edit HEAD
            ;;
    esac
    echo ""
fi

# 2. Identify known REQUIRED modules from git history so we don't remove them again.
# This looks for 'Revert' commits created by this script in the past.
KNOWN_REQUIRED_REGEX=$(git log --format="%s" | grep '^Revert "Assumption: we do not need ' | sed -E 's/Revert "Assumption: we do not need (.*) to boot."/\1/' | tr '\n' '|' | sed 's/|$//' || true)

# 3. Find candidate modules to remove
CANDIDATES=$(grep -n -E '^[ \t]+/[a-zA-Z0-9_/-]+$' "$CONFIG_FILE" || true)

if [[ -z "$CANDIDATES" ]]; then
    echo "No kernel module lines found in $CONFIG_FILE."
    exit 1
fi

# Filter out known required modules so we don't get stuck in an infinite loop
if [[ -n "$KNOWN_REQUIRED_REGEX" ]]; then
    CANDIDATES=$(echo "$CANDIDATES" | grep -v -E "/($KNOWN_REQUIRED_REGEX)$" || true)
fi

if [[ -z "$CANDIDATES" ]]; then
    echo "Congratulations! All remaining modules in $CONFIG_FILE have been tested and are REQUIRED."
    exit 0
fi

# 4. Pick a random victim
TARGET=$(echo "$CANDIDATES" | shuf -n 1)

LINE_NUM=$(echo "$TARGET" | cut -d ':' -f 1)
MODULE_PATH=$(echo "$TARGET" | cut -d ':' -f 2- | awk '{print $1}')
MODULE_NAME=$(basename "$MODULE_PATH")

echo "========================================================="
echo "RUSSIAN ROULETTE: Testing removal of '$MODULE_NAME' (Line $LINE_NUM)"
echo "========================================================="

# 5. Execute removal
sed -i "${LINE_NUM}d" "$CONFIG_FILE"

git add "$CONFIG_FILE"
git commit -m "Assumption: we do not need $MODULE_NAME to boot."

# 6. Build and Reboot
echo "Running mkosi sysupdate and rebooting..."
../mkosi/bin/mkosi -ff sysupdate -- update --reboot
