#!/bin/bash
# Huaicheng Li <lhcwhu@gmail.com>
# Run VM with CXL Memory emulation

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
	#exit
fi

# -numa node,cpus=0-3,nodeid=0 \
# -numa node,cpus=4-7,nodeid=1 \
# -m 16G \
# mem-merge=on|off

#
    #-object memory-backend-ram,size=4096M,policy=bind,host-nodes=0,id=ram-node0,prealloc=on \
    #-numa node,nodeid=0,cpus=0-1,memdev=ram-node0 \
    #-object memory-backend-ram,size=8192M,policy=bind,host-nodes=1,id=ram-node1,prealloc=on \
    #-numa node,nodeid=1,cpus=2-7,memdev=ram-node1 \


    #-device virtio-scsi-pci,id=scsi1 \
    #-device scsi-hd,drive=hd1 \
    #-drive file=/users/huaichel/images/caspian2.qcow2,if=none,aio=native,cache=none,format=qcow2,id=hd1


# $1: vnode ID, 0 or 1
# $2: host/backing node ID to allocate VM memory from
# $3: mem size in MB
# $4: vcpus for this vnode, e.g. "0-7" (optional -> computeless-vnode)

function configure_vnode()
{
    vnodeid=$1
    hnodeid=$2
    memsz=$3
    nodecpus=$4

    cmd="-object memory-backend-ram,size=${memsz}M,policy=bind,host-nodes=${hnodeid},id=ram-node${vnodeid},prealloc=on,prealloc-threads=8 "

    cmd=${cmd}"-numa node,nodeid=${vnodeid},"

    if [[ $nodecpus != "" ]]; then
        cmd=${cmd}"cpus=$nodecpus,"
    fi

    cmd=${cmd}"memdev=ram-node${vnodeid}"

    echo $cmd
}

MEMSZ_MB=65536

L100=$(configure_vnode 0 0 $MEMSZ_MB 0-7)
L0=$(configure_vnode 0 1 $MEMSZ_MB)

# 75% local memory configuration
VNODE0_MEMSZ_MB=$((MEMSZ_MB * 3 / 4))
VNODE1_MEMSZ_MB=$((MEMSZ_MB - VNODE0_MEMSZ_MB))
L75="$(configure_vnode 0 0 $VNODE0_MEMSZ_MB 0-7)"" ""$(configure_vnode 1 1 $VNODE1_MEMSZ_MB)"

# 50% local memory configuration
VNODE0_MEMSZ_MB=$((MEMSZ_MB / 2))
VNODE1_MEMSZ_MB=$((MEMSZ_MB - VNODE0_MEMSZ_MB))
L50="$(configure_vnode 0 0 $VNODE0_MEMSZ_MB 0-7)"" ""$(configure_vnode 1 1 $VNODE1_MEMSZ_MB)"

# 25% local memory configuration
VNODE0_MEMSZ_MB=$((MEMSZ_MB / 4))
VNODE1_MEMSZ_MB=$((MEMSZ_MB - VNODE0_MEMSZ_MB))
L25="$(configure_vnode 0 0 $VNODE0_MEMSZ_MB 0-7)"" ""$(configure_vnode 1 1 $VNODE1_MEMSZ_MB)"

function configure_vdisk()
{
    cmd="-device virtio-scsi-pci,id=scsi0 "
    cmd=${cmd}"-device scsi-hd,drive=hd0 "
    cmd=${cmd}"-drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0"

    echo $cmd
}

#configure_vdisk

function configure_vnic()
{
    cmd="-net user,hostfwd=tcp::8080-:22 "
    cmd=${cmd}"-net nic,model=virtio "
    cmd=${cmd}"-device virtio-net,netdev=network0 "
    cmd=${cmd}"-netdev tap,id=network0,ifname=tap0,script=no,downscript=no"

    echo ${cmd}
}

QEMU_CMD_PREFIX="sudo x86_64-softmmu/qemu-system-x86_64 \
    -name "CaspianVM" \
    -machine type=pc,accel=kvm,mem-merge=off \
    -enable-kvm \
    -cpu host \
    -smp cpus=8 \
    -m ${MEMSZ_MB}M"

QEMU_CMD_SUFFIX="$(configure_vdisk) \
    $(configure_vnic) \
    -nographic \
    -qmp unix:./qmp-sock,server,nowait"

# run the main experiments across different VM vNUMA configurations
for L in "${L100}" "${L75}" "${L50}" "${L25}" "${L0}"; do
    VM_RUN_CMD=${QEMU_CMD_PREFIX}" "$L" "${QEMU_CMD_SUFFIX}

    echo ${VM_RUN_CMD}
    exit

    ${VM_RUN_CMD} > log 2>&1 &

    sleep 10
    # pin vCPUs to pCPUs explicitly
    echo "===> Pinning vCPUs to pCPUs ..."
    ./pin.sh

    echo "===> Sleep 60s to wait for the VM to be up ..."
    sleep 60

    while [[ $vmstatus != "ok" ]]; do
        #echo "===> Trying to connect to the VM ..."
        sleep 10
        vmstatus=$(ssh -p8080 -o BatchMode=yes -o ConnectTimeout=5 huaicheng@localhost echo ok 2>&1)
    done

    sleep 5
    #ssh -p8080 huaicheng@localhost "sudo numactl --hardware && echo && echo; sudo shutdown -h now"
    ssh -p8080 huaicheng@localhost "cd cpuspec2017 && source shrc && runcpu 657.xz_s && mv result result.$(date +%h%d%H%M) && sleep 10 && echo && echo; sudo shutdown -h now"
    #ssh -p8080 huaicheng@localhost "sleep 10 && ./run-mutilate.sh $(date +%m%d) && sleep 10 && echo && echo; sudo shutdown -h now"


    echo "===> Waiting for VM to shutdown"
    sleep 60
    # if VM is still up, let's kill it forcefully
    for pid in $(ps -ef | grep qemu-system-x86_64 | grep -v grep | awk '{print $2}'); do
        sudo kill -9 $pid
    done

    sleep 30

done

