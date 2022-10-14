
# Notes for running Caspian experiments in a VM #

- Probably we need to passthough a NIC to the VM, so first step is
  - To make VFIO work, change host grub: "intel_iommu=on iommu=pt", reboot
  - ``vfio-bind 0000:5e:00.0``, ``vfio-bind 0000:5e:00.1``

- Start the VM

- Run Hadoop/HDFS inside the VM, setup HiBench and Spark

- Then run ``run-exp.sh`` from the host
