# README for CXL-emulation and Experiments HowTo  #

### CXL Emulation on regular 2-socket (2S) server systems ###

We mainly emulate the following two characteristics of CXL memory

- Latency: ~150ns
- No local CPU which can directly accesses it, i.e., CXL-memory treated as a
  "computerless" node

The CXL latency is similar to the latency of one NUMA hop on modern 2S systems,
thus, we simulate the CXL memory using the memory on the remote NUMA node and
disables all the cores on the remote NUMA node to simulate the "computeless"
node behavior.

In this repo, the CXL-simulation is mainly done via a few scripts, check
``cxl-global.sh`` and the ``run-xxx.sh`` under each workload folder (e.g.,
``cpu2017``, ``gapbs``, etc.).

These scripts dynamically adjust the system configuration to simulate a certain
percentage of CXL memory in the system, and run workloads againt such
scenarios.


### Configuring Local/CXL-DRAM Splits ###

One major setup we are benchmarking is to adjust the perentage of CXL-memory
being used to run a certain workload and observe the perfomrance impacts
(compared to pure local DRAM "ideal" cases). For example, the common ratios the
scripts include "100/0" (the 100% local DRAM case, no CXL), "95/5", "90/10"
(90% local DRAM + 10% CXL), "85/15", "80/20", "75/25", "50/50", "25/75", etc. 

To provision correct amount of local/CXL memory for the above split ratios, we
need to profile the peak memory usage of the target workload. This is usually
done via monitoring tools such as ``pidstat`` (the ``RSS`` field reported in
the memory usage).


### A Simple HowTo using CPUSPEC ###

Under folder ``cpu2017``, ``run-cpu2017.sh`` is the main entry to run a series
of experiments under various split configurations. The script reads the
profiled information in a workload input file (e.g., ``wi.txt``), where the
first column is the workload name and the second column is the peak memory
consumption of the workload. Based on these, ``run-cpu2017.sh`` will iterate
over a series of predefined split-ratios and run the experiments one by one.
The scripts writes the logs and outputs to ``rst`` folder.

One could co-run profiling utilities such as ``emon`` or ``Intel Vtune``
together with the workload to get architecture-level metrics to help analyze
the workload performance. Make sure Vtune is installed first before running the
script.
