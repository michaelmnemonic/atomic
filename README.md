# atomic
Atomic linux images using systemds mkosi

sysexts are copied to /var/lib/extensions
confext are copied to /var/lib/confexts

run0 /usr/lib/systemd/systemd-sysupdate --definition mkosi.sysupdate/ --transfer-source mkosi.output/ update --reboot