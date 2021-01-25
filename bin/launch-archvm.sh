#!/bin/bash
set -euxo pipefail
disk=$1
hostname=${disk%%.*}
ulimit -l 1024000
exec qemu-system-x86_64 -enable-kvm \
       -drive file=$disk,if=virtio \
       -name "$hostname" \
       -bios /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
       -cpu host -smp 2 -machine type=q35 -m 2G \
       -netdev tap,helper=/usr/lib/qemu/qemu-bridge-helper,id=hn0 \
       -device virtio-net-pci,netdev=hn0,mac=$(./qemu-mac-hasher.py "$hostname"),id=nic1 \
       -device virtio-balloon
