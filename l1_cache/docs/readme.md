# L1 Data Cache with Way Predictor and Stale Tracking

This project implements a 4-way set-associative, write-back/write-allocate L1 data cache sized for 64 sets with 16-byte cache lines. The RTL is written in Verilog while the verification environment uses SystemVerilog.

## Key Features
- **Tiny way predictor**: keeps a 2-bit predicted way per set to shortcut tag comparisons and exposes predictor hit/miss counters.
- **Selective stale tracker**: models per-line age counters with a programmable threshold and reports stale events for refresh-style experiments.
- **Performance counters**: hits, misses, (dirty) evictions, predictor hit/miss, and stale events are tracked and visible at the top level.

## Project Layout
```
l1_cache/
  rtl/        # Synthesizable cache RTL and support blocks
  tb/         # SystemVerilog testbench, traffic generator, memory model
  synth/      # Yosys synthesis script
  sta/        # Example SDC constraint
  docs/       # Documentation
```

## Simulation
The `tb/cache_tb.sv` testbench instantiates the cache, memory model, and traffic generator. Run it with any SystemVerilog-capable simulator, for example with Icarus:

```sh
cd l1_cache
iverilog -g2012 -o cache_tb.vvp rtl/*.v tb/memory_model.v tb/traffic_gen.sv tb/cache_tb.sv
vvp cache_tb.vvp
```

The testbench drives directed, random, and stale-inducing traffic and prints a summary of all performance counters. Basic assertions ensure cache activity, predictor training, and stale events occurred before the simulation ends.

## Synthesis and Timing
A reference Yosys script is provided in `synth/synth.ys`. It reads all RTL, synthesizes `l1_cache_top`, and emits both JSON and Verilog netlists. Static timing can be evaluated with the example 200 MHz constraint stored in `sta/constraints.sdc`.

## Extending the Design
- Adjust `NUM_SETS`, `NUM_WAYS`, or `LINE_BYTES` parameters in `l1_cache_top`/`l1_cache_core` to explore different organizations.
- Replace the simple pseudo-LRU with a different policy or add prefetching.
- Expand the stale tracker with per-set thresholds or refresh commands.
- Integrate a more realistic memory interface (AXI/AHB) for system-level studies.

