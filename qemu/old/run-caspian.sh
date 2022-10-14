#!/bin/bash
# Huaicheng Li <lhcwhu@gmail.com>
# Run VM with FEMU support: FEMU as a black-box SSD (FTL managed by the device)

# image directory
IMGDIR=$HOME/images
# virtual machine disk image
OSIMGF=$IMGDIR/caspian.qcow2

if [[ ! -e "$OSIMGF" ]]; then
	echo ""
	echo "VM disk image couldn't be found ..."
	echo "Please prepare a usable VM image and place it as $OSIMGF"
	echo "Once VM disk image is ready, please rerun this script again"
	echo ""
	exit
fi

sudo x86_64-softmmu/qemu-system-x86_64 \
    -name "CaspianVM" \
    -enable-kvm \
    -cpu host \
    -smp 4 \
    -m 16G \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    -net user,hostfwd=tcp::8080-:22 \
    -net nic,model=virtio \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait 2>&1 | tee log
