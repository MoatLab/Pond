
# SPEC CPU 2017 HOWTO
---

- Follow the SEPC CPU instructions to compile the workloads, and copy the
binary+data into corresponding workload folders

- Under each workload folder, there is a ``cmd.sh`` to run the SPEC workload,
  e.g., ``519.lbm_r/cmd.sh``,

```
#!/bin/bash
ulimit -s unlimited
export OMP_NUM_THREADS=1
export OMP_STACKSIZE=122880
./lbm_r_base.mytest-m64 3000 reference.dat 0 0 100_100_130_ldc.of > lbm.out 2>> lbm.err
```

- ``run-cpu2017.sh`` will execute the ``cmd.sh`` for each workoad under
  different memory configurations
  - The scripts read an input file ``w.txt`` which specifies the workload name
    (1st column) and memory footprint of the workload (2nd column)
  - Memory footprint is profiled offline during a test run
  - The performance results and profiling log files will be under ``rst/``
