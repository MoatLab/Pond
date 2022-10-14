#!/bin/bash
# Huaicheng Li <lhcwhu@gmail.com>
# Run the VM

# Image directory
#IMGDIR=/tdata
IMGDIR=/pdata/caspian
# Virtual machine disk image
#OSIMGF=$IMGDIR/caspian-new.qcow2
OSIMGF=$IMGDIR/caspian.qcow2


if [[ ! -e "$OSIMGF" ]]; then
	echo ""
	echo "VM disk image couldn't be found ..."
	echo "Please prepare a usable VM image and place it as $OSIMGF"
	echo "Once VM disk image is ready, please rerun this script again"
	echo ""
	exit
fi

sudo qemu-system-x86_64 \
    -name "CaspianVM-Spark" \
    -machine type=pc,accel=kvm,mem-merge=off \
    -enable-kvm \
    -cpu host \
    -smp 8 \
    -m 65536M \
    -object memory-backend-ram,size=65536M,policy=bind,host-nodes=0,id=ram-node0,prealloc=on \
    -numa node,nodeid=0,cpus=0-7,memdev=ram-node0 \
    -device virtio-scsi-pci,id=scsi0 \
    -device scsi-hd,drive=hd0 \
    -drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
    -drive file=/dev/sda4,format=raw,if=virtio \
    -net user,hostfwd=tcp::8080-:22 \
    -net nic,model=virtio \
    -device vfio-pci,host=5e:00.1 \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait
