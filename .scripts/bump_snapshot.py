#!/usr/bin/env python3

import json
import re
import urllib.request


def get_latest_debian_snapshot():
    url = "http://snapshot.debian.org/mr/timestamp/"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            # The API returns a dictionary where 'result' contains the archives
            # 'debian' is the key for the main archive
            timestamps = data.get("result", {}).get("debian", [])
            if timestamps:
                return timestamps[-1]
            else:
                print("Could not find any Debian timestamps in the API response.")
                return None
    except Exception as e:
        print(f"Error fetching snapshot data: {e}")
        return None


def update_mkosi_conf(latest_snapshot):
    conf_file = "mkosi.conf"
    try:
        with open(conf_file, "r") as f:
            content = f.read()

        # Find the current snapshot
        match = re.search(r"^Snapshot=(.*)$", content, re.MULTILINE)
        if match:
            current_snapshot = match.group(1)
            if current_snapshot == latest_snapshot:
                print(f"Snapshot is already up-to-date: {current_snapshot}")
                return

            # Replace the snapshot
            new_content = re.sub(
                r"^Snapshot=.*$",
                f"Snapshot={latest_snapshot}",
                content,
                flags=re.MULTILINE,
            )

            with open(conf_file, "w") as f:
                f.write(new_content)

            print(
                f"Updated {conf_file}: Snapshot bumped from {current_snapshot} to {latest_snapshot}"
            )
        else:
            print(f"Could not find 'Snapshot=' in {conf_file}")

    except FileNotFoundError:
        print(f"Error: {conf_file} not found in the current directory.")
    except Exception as e:
        print(f"Error updating {conf_file}: {e}")


if __name__ == "__main__":
    print("Fetching latest Debian snapshot from snapshot.debian.org...")
    latest_snapshot = get_latest_debian_snapshot()

    if latest_snapshot:
        print(f"Latest snapshot available: {latest_snapshot}")
        update_mkosi_conf(latest_snapshot)
    else:
        print("Failed to get the latest snapshot. Exiting.")
