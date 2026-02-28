#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="mkosi.conf.d/lenovo-x13s/mkosi.conf"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found. Please run this script from the project root (atomic/)."
    exit 1
fi

STATE_DIR=".scripts/.roulette_state_dir"
mkdir -p "$STATE_DIR"

QUEUE_FILE="$STATE_DIR/queue"
LAST_TEST_FILE="$STATE_DIR/last_test"
REQUIRED_FILE="$STATE_DIR/required"

touch "$REQUIRED_FILE"
touch "$QUEUE_FILE"

# 1. Handle previous state from git history (legacy script compatibility)
LAST_MSG=$(git log -1 --format="%s" || true)
if [[ ! -f "$LAST_TEST_FILE" && "$LAST_MSG" == "Assumption: we do not need"* ]]; then
    LAST_MOD=$(echo "$LAST_MSG" | sed -E 's/Assumption: we do not need (.*) to boot./\1/')
    echo "========================================================="
    echo "LAST TEST (Legacy): Removed kernel module '$LAST_MOD'"
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
            echo "Boot failed. Reverting the commit..."
            git revert --no-edit HEAD
            ;;
    esac
    echo ""
fi

# 2. Extract previously known REQUIRED modules from git history (legacy)
if [[ ! -s "$REQUIRED_FILE" ]]; then
    KNOWN_BASENAMES=$(git log --format="%s" | grep '^Revert "Assumption: we do not need ' | sed -E 's/Revert "Assumption: we do not need (.*) to boot."/\1/' || true)
    for b in $KNOWN_BASENAMES; do
        # find the full path in the config file if it exists
        FULL_PATH=$(grep -E "^[ \t]+/[a-zA-Z0-9_/-]+$b$" "$CONFIG_FILE" | awk '{print $1}' || true)
        if [[ -n "$FULL_PATH" ]]; then
            echo "$FULL_PATH" >> "$REQUIRED_FILE"
        fi
    done
    sort -u "$REQUIRED_FILE" -o "$REQUIRED_FILE" || true
fi

# 3. Handle previous state from new chunk-based script
if [[ -f "$LAST_TEST_FILE" ]]; then
    mapfile -t LAST_TEST < "$LAST_TEST_FILE"
    NUM_MODS=${#LAST_TEST[@]}

    if [[ $NUM_MODS -gt 0 ]]; then
        echo "========================================================="
        echo "LAST TEST: Removed $NUM_MODS modules:"
        for mod in "${LAST_TEST[@]}"; do
            echo "  - $mod"
        done
        echo "========================================================="
        echo "If you are reading this, your system is running."
        echo "Did the system boot normally on the NEW image?"
        echo "(Answer 'n' if it failed and you booted into the A/B fallback)"
        read -r -p "Was the assumption correct? [y/N]: " RESP

        case "$RESP" in
            [yY]|[yY][eE][sS])
                echo "Awesome! The assumption holds. These $NUM_MODS modules are permanently removed."
                rm -f "$LAST_TEST_FILE"
                ;;
            *)
                echo "Boot failed. Reverting the commit..."
                git revert --no-edit HEAD

                if [[ $NUM_MODS -eq 1 ]]; then
                    echo "'${LAST_TEST[0]}' is REQUIRED. Marking it."
                    echo "${LAST_TEST[0]}" >> "$REQUIRED_FILE"
                    sort -u "$REQUIRED_FILE" -o "$REQUIRED_FILE"
                else
                    echo "Chunk failed. Splitting into smaller chunks for isolated testing..."
                    HALF=$(( NUM_MODS / 2 ))

                    # Split into CHUNK1 and CHUNK2
                    CHUNK1=("${LAST_TEST[@]:0:$HALF}")
                    CHUNK2=("${LAST_TEST[@]:$HALF}")

                    # Prepend to queue (depth-first approach)
                    TEMP_Q=$(mktemp)
                    echo "${CHUNK1[@]}" > "$TEMP_Q"
                    echo "${CHUNK2[@]}" >> "$TEMP_Q"
                    if [[ -s "$QUEUE_FILE" ]]; then
                        cat "$QUEUE_FILE" >> "$TEMP_Q"
                    fi
                    mv "$TEMP_Q" "$QUEUE_FILE"
                fi
                rm -f "$LAST_TEST_FILE"
                ;;
        esac
        echo ""
    else
        rm -f "$LAST_TEST_FILE"
    fi
fi

# 4. Get current valid candidates from config
mapfile -t CURRENT_CANDIDATES < <(grep -E '^[ \t]+/[a-zA-Z0-9_/-]+$' "$CONFIG_FILE" | awk '{print $1}')

if [[ ${#CURRENT_CANDIDATES[@]} -eq 0 ]]; then
    echo "No kernel module lines found in $CONFIG_FILE."
    exit 1
fi

# 5. Initialize queue if empty
if [[ ! -s "$QUEUE_FILE" ]]; then
    declare -a VALID_CANDIDATES=()
    for mod in "${CURRENT_CANDIDATES[@]}"; do
        if ! grep -q -x -F "$mod" "$REQUIRED_FILE"; then
            VALID_CANDIDATES+=("$mod")
        fi
    done

    if [[ ${#VALID_CANDIDATES[@]} -eq 0 ]]; then
        echo "Congratulations! All remaining modules in $CONFIG_FILE have been tested and are REQUIRED."
        exit 0
    fi

    echo "Queue is empty. Initializing with ${#VALID_CANDIDATES[@]} valid candidates in chunks of 10..."
    CHUNK_SIZE=10
    for ((i=0; i<${#VALID_CANDIDATES[@]}; i+=CHUNK_SIZE)); do
        # Extract up to CHUNK_SIZE elements
        END=$(( i + CHUNK_SIZE ))
        if [[ $END -gt ${#VALID_CANDIDATES[@]} ]]; then
            END=${#VALID_CANDIDATES[@]}
        fi

        # We need to print them space separated
        CHUNK_ARR=("${VALID_CANDIDATES[@]:$i:$((END-i))}")
        echo "${CHUNK_ARR[@]}" >> "$QUEUE_FILE"
    done
fi

# 6. Pop the next valid chunk from queue
declare -a NEXT_CHUNK=()
while [[ -s "$QUEUE_FILE" ]]; do
    # read first line into array
    read -r -a CHUNK < "$QUEUE_FILE" || true
    # remove first line
    tail -n +2 "$QUEUE_FILE" > "$QUEUE_FILE.tmp" && mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Filter chunk: only keep modules that are STILL in CURRENT_CANDIDATES
    declare -a FILTERED_CHUNK=()
    for mod in "${CHUNK[@]}"; do
        for c in "${CURRENT_CANDIDATES[@]}"; do
            if [[ "$mod" == "$c" ]]; then
                FILTERED_CHUNK+=("$mod")
                break
            fi
        done
    done

    if [[ ${#FILTERED_CHUNK[@]} -gt 0 ]]; then
        NEXT_CHUNK=("${FILTERED_CHUNK[@]}")
        break
    fi
done

if [[ ${#NEXT_CHUNK[@]} -eq 0 ]]; then
    # Queue is exhausted, re-run to verify
    echo "Queue exhausted. Verifying completion..."
    rm -f "$QUEUE_FILE"
    exec "$0"
fi

# 7. Execute removal
echo "========================================================="
echo "RUSSIAN ROULETTE: Testing removal of ${#NEXT_CHUNK[@]} modules:"
for mod in "${NEXT_CHUNK[@]}"; do
    echo "  - $mod"
    # escape slashes for sed
    ESCAPED_MOD=$(echo "$mod" | sed 's/\//\\\//g')
    sed -i "/^[ \t]*${ESCAPED_MOD}$/d" "$CONFIG_FILE"
done
echo "========================================================="

# Save to last test (one per line)
printf "%s\n" "${NEXT_CHUNK[@]}" > "$LAST_TEST_FILE"

MOD_NAMES=""
if [[ ${#NEXT_CHUNK[@]} -eq 1 ]]; then
    MOD_NAMES=$(basename "${NEXT_CHUNK[0]}")
    COMMIT_MSG="Assumption: we do not need $MOD_NAMES to boot."
else
    COMMIT_MSG="Assumption: we do not need ${#NEXT_CHUNK[@]} modules to boot."
fi

git add "$CONFIG_FILE"
git commit -m "$COMMIT_MSG"

# 8. Build and Reboot
echo "Running mkosi sysupdate and rebooting..."
../mkosi/bin/mkosi -ff sysupdate -- update --reboot
