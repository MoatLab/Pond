
```

 ______                _
(_____ \              | |
 _____) )__  ____   __| |
|  ____/ _ \|  _ \ / _  |
| |   | |_| | | | ( (_| |
|_|    \___/|_| |_|\____|  - Compute Express Link (CXL) based Memory Pooling Systems

```
---
---
---


# README for CXL-emulation and Experiments HowTo #

### Cite our Pond paper (ASPLOS '23): 

>> Pond: CXL-Based Memory Pooling Systems for Cloud Platforms

**The preprint of the paper can be found [here](https://huaicheng.github.io/p/asplos23-pond.pdf).**

```
@InProceedings{pond.asplos23,
  author = {Huaicheng Li and Daniel S. Berger and Lisa Hsu and Daniel Ernst and Pantea Zardoshti and Stanko Novakovic and Monish Shah and Samir Rajadnya and Scott Lee and Ishwar Agarwal and Mark D. Hill and Marcus Fontoura and Ricardo Bianchini},
  title = "{Pond: CXL-Based Memory Pooling Systems for Cloud Platforms}",
  booktitle = {Proceedings of the 28th ACM International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS)},
  address = {Vancouver, BC Canada},
  month = {March},
  year = {2023}
}

```

### What is this repo about?

This repo open-sources our approach for CXL simulation and evaluations (mainly
some scripts). It is not a full-fledged open-source version of Pond design.


### CXL Emulation on regular 2-socket (2S) server systems ###

We mainly emulate the following two characteristics of Compute Express Link
(CXL) attached DRAM:

- Latency: ~150ns
- No local CPU which can directly accesses it, i.e., CXL-memory treated as a
  "computeless/cpuless" node

The CXL latency is similar to the latency of one NUMA hop on modern 2S systems,
thus, we simulate the CXL memory using the memory on the remote NUMA node and
disables all the cores on the remote NUMA node to simulate the "computeless"
node behavior.

In this repo, the CXL-simulation is mainly done via a few scripts, check
``cxl-global.sh`` and the ``run-xxx.sh`` under each workload folder (e.g.,
``cpu2017``, ``gapbs``, etc.).

These scripts dynamically adjust the system configuration to simulate a certain
percentage of CXL memory in the system, and run workloads against such
scenarios.


### Configuring Local/CXL-DRAM Splits ###

One major setup we are benchmarking is to adjust the perentage of CXL-memory
being used to run a certain workload and observe the performance impacts
(compared to pure local DRAM "ideal" cases). For example, the common ratios the
scripts include "100/0" (the 100% local DRAM case, no CXL), "95/5", "90/10"
(90% local DRAM + 10% CXL), "85/15", "80/20", "75/25", "50/50", "25/75", etc. 

To provision correct amount of local/CXL memory for the above split ratios, we
need to profile the peak memory usage of the target workload. This is usually
done via monitoring tools such as ``pidstat`` (the ``RSS`` field reported in
the memory usage).


### A Simple HowTo using SPEC CPU 2017 ###

Under folder ``cpu2017``, ``run-cpu2017.sh`` is the main entry to run a series
of experiments under various split configurations. The script reads the
profiled information in a workload input file (e.g., ``wi.txt``), where the
first column is the workload name and the second column is the peak memory
consumption of the workload. Based on these, ``run-cpu2017.sh`` will iterate
over a series of predefined split-ratios and run the experiments one by one.
The scripts writes the logs and outputs to ``rst`` folder.

One could co-run profiling utilities such as ``emon`` or ``Intel Vtune``
together with the workload to collect architecture-level metrics for
performance analysis. Make sure Intel Vtune is installed first before running
the script.
