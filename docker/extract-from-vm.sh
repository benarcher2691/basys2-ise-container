#!/bin/sh
# Pull the ISE 14.7 install out of AMD's "ISE 14.7 for Windows 10" VM
# download (Xilinx_ISE_14.7_Win10_14.7_VM_0213_1.zip), which ships a
# VirtualBox VM (Oracle Linux 6.4) with ISE 14.7 (build 14.7_1015_1)
# installed in /opt/Xilinx. Writes ise-14.7-ISE_DS.tar, the input for
# docker/build.sh.
#
# Usage: docker/extract-from-vm.sh [zip] [out-dir]
#   zip      default ~/Downloads/Xilinx_ISE_14.7_Win10_14.7_VM_0213_1.zip
#   out-dir  default ~/Downloads/xilinx
#
# Needs about 17 GB (OVA) + 12 GB (tar) on the Mac and ~40 GB in Docker's
# disk for the raw image (Docker volume ise-vm-work). The zip is only read.
set -eu

zip=${1:-$HOME/Downloads/Xilinx_ISE_14.7_Win10_14.7_VM_0213_1.zip}
out=${2:-$HOME/Downloads/xilinx}
vm=$out/vm

# 1. The OVA inside the zip is a tar of the VM description and its disk.
if [ ! -f "$vm/14.7_VM-disk001.vmdk" ]; then
    mkdir -p "$vm"
    unzip -p "$zip" ova/14.7_VM.ova | tar -xf - -C "$vm"
fi

# 2. In a privileged Linux container: convert the disk to raw, mount its
#    root partition read-only, and tar the parts of ISE_DS the command-line
#    flow needs. EDK, PlanAhead and SysGen (~9 GB) are left out;
#    settings64.sh skips components that aren't there.
docker volume create ise-vm-work >/dev/null
docker run --rm --privileged --platform linux/arm64 \
    -v "$vm":/vm:ro -v ise-vm-work:/work -v "$out":/out \
    ubuntu:24.04 bash -c '
set -eu
apt-get update -qq >/dev/null && apt-get install -y -qq qemu-utils >/dev/null
[ -f /work/disk.raw ] || qemu-img convert -O raw /vm/14.7_VM-disk001.vmdk /work/disk.raw
mkdir -p /mnt/vm
mount -o ro,loop,offset=$((2048 * 512)) /work/disk.raw /mnt/vm   # partition 1
cd /mnt/vm/opt/Xilinx/14.7
grep -q "imageBuildVersion=14.7_1015_1" ISE_DS/ISE/fileset.txt
tar -cf /out/ise-14.7-ISE_DS.tar --numeric-owner \
    ISE_DS/ISE ISE_DS/common ISE_DS/.xinstall ISE_DS/settings64.sh ISE_DS/settings32.sh
cd /
umount /mnt/vm
'
ls -l "$out/ise-14.7-ISE_DS.tar"
echo "Done. Optional clean-up: rm -r '$vm'; docker volume rm ise-vm-work"
