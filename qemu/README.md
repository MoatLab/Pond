
### Pond CXL VM

- Simulate a CXL VM with tow virtual NUMA nodes
  - vNode 0: CPU + local DRAM (from host node 0)
  - vNode 1: simulated CXL DRAM (backed by node 1 DRAM on host)

- The host needs to be a 2-socket server

- Pond CXL VM Architecture


```
         +-----------------------------------+
         |                                   |
         |         Guest OS / Linux          |
         |                                   |
         +-------^^-----------------^^-------+
                 ||                 ||        
                 vv                 vv        
         +---------------+   +---------------+
         | vNode 0 DRAM  |   | vNode 1 DRAM  |
         +---------------+   +---------------+
         +---+ +---+ +---+   +---------------+
         |cpu| |cpu| |cpu|   |               |
         +---+ +---+ +---+   +---------------+
       ══════════════════════════════════════════
                ║║                  ║║
        ╔════════════════╗   ╔═══════════════╗
        ║   Host Node 0  ╠═══║  Host Node 1  ║
        ╚════════════════╝   ╚═══════════════╝

```
