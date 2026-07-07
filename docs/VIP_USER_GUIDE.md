# PCIe Gen5 DLL VIP — User Guide

> **Baseline**: PCIe Base Specification Rev 5.0, variable-length packet (non-FLIT) mode, VC0 only.
> **Simulator**: Questa with UVM 1.2.
> **Scope of this guide**: Getting started, wiring (VIP-to-VIP and VIP-to-RTL), writing test
> scenarios, error injection, link-control, and analysis component tuning.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Repository Layout](#3-repository-layout)
4. [Compilation & First Run](#4-compilation--first-run)
5. [VIP-to-VIP Wiring (B2B)](#5-vip-to-vip-wiring-b2b)
6. [VIP-to-RTL Wiring](#6-vip-to-rtl-wiring)
7. [Configuration Objects](#7-configuration-objects)
8. [Writing a New Test](#8-writing-a-new-test)
9. [Error Injection via Callbacks](#9-error-injection-via-callbacks)
10. [Link-Control Sequences](#10-link-control-sequences)
11. [Report Catcher — Handling Expected Errors](#11-report-catcher--handling-expected-errors)
12. [Analysis Components Reference](#12-analysis-components-reference)
13. [Coverage Collection](#13-coverage-collection)
14. [Common Pitfalls](#14-common-pitfalls)

---

## 1. Overview

This VIP verifies the **Data Link Layer Control and Management State Machine (DLCMSM)**
of a PCIe Gen5 endpoint or root complex over the **LPIF** (Link-layer / PHY Interface).

The VIP is **symmetric and role-parameterised**: a single `pcie_dll_env` class is
instantiated twice — once as `env_rc` (Root Complex) and once as `env_ep` (Endpoint) —
with identical code but a `ROLE_RC` / `ROLE_EP` flag driving all conditional logic.

```
Test
 ├── env_rc  (ROLE_RC)  ──[rc_if]──┐
 │                                  ├── mock_phy_crossbar / RTL DUT
 └── env_ep  (ROLE_EP)  ──[ep_if]──┘
```

Each env contains:
- **`pcie_dll_agent`** — Tx driver, Tx monitor, Rx monitor, FSM state manager, sequencer
- **`pcie_dll_scoreboard`** — protocol-level checks
- **`pcie_dll_fc_watchdog`** — 34 µs DLLP-arrival interval enforcement
- **`pcie_dll_coverage` × 2** — Tx-path and Rx-path coverage

The **DLCMSM** follows this path for a normal bring-up:

```
DL_INACTIVE → DL_FEATURE_EXCH → DL_INIT_FC1 → DL_INIT_FC2 → DL_ACTIVE
```

`DL_FEATURE_EXCH` is optional; it is skipped when both sides have `scaled_fc_supported = 0`.

---

## 2. Prerequisites

| Requirement | Details |
|---|---|
| Simulator | Questa / ModelSim with SystemVerilog + UVM 1.2 support |
| UVM library | Compiled and on the simulator's search path (`-L uvm_lib` or bundled) |
| Tool version | Tested on QuestaSim 2021.3+; earlier versions may need `-sv` flag added to `vlog` |
| No external IP | All VIP code is self-contained; no third-party packages required |

---

## 3. Repository Layout

```
pcie-gen5-dll-vip/
├── tb/
│   ├── tb_top.sv          ← Top module: clock, reset, interface instantiation, run_test()
│   └── pcie_lpif_if.sv    ← LPIF SV interface + 8 SVA properties + 3 clocking blocks
│
├── rtl/
│   └── mock_phy_crossbar.sv  ← B2B loopback (VIP-to-VIP use)
│
├── docs/
│   ├── UVM_TESTBENCH_ARCHITECTURE_PLAN.md  ← Full architecture reference
│   └── VIP_USER_GUIDE.md                   ← This file
│
└── vip/
    ├── pcie_dll_pkg.sv    ← Master package — all `include directives in compile order
    ├── env/               ← Config objects + environment
    ├── agents/            ← Driver, monitors, FSM state manager, callbacks
    ├── transactions/      ← Sequence items (DLLP, TLP, IF-control)
    ├── sequences/         ← Pre-built traffic sequences
    ├── scoreboards/       ← Scoreboard + FC watchdog
    ├── coverage/          ← Functional coverage
    ├── helpers/           ← CRC utility, error classifier, report catcher
    └── tests/             ← Base test + 7 derived test scenarios
```

The single entry point for compilation is **`vip/pcie_dll_pkg.sv`**. All VIP classes are
included inside this package in the correct dependency order — you never need to manage
individual file ordering yourself.

---

## 4. Compilation & First Run

### 4.1 Questa / ModelSim — one-shot compile + simulate

From inside the `vip/` directory:

```tcl
# Compile (run once, or after any source change)
vlog ../tb/pcie_lpif_if.sv \
     ../rtl/mock_phy_crossbar.sv \
     pcie_dll_pkg.sv \
     ../tb/tb_top.sv

# Simulate with a specific test
vsim -coverage -voptargs="+acc" \
     +UVM_TESTNAME=test_base_with_feature \
     work.tb_top \
     -do "run -all; quit -sim"
```

The same commands are packaged in **`vip/run.do`**; just update the `UVM_TESTNAME` value
and execute `do run.do` inside the Questa GUI or `-c` (batch) mode.

### 4.2 Compile order rules

The strict compile order inside `pcie_dll_pkg.sv` is:

```
1. pcie_lpif_if.sv          (interface — must come before the package)
2. Enums & structs           (pcie_dll_types.sv, pcie_dll_structs.sv)
3. Config objects            (env_cfg → partner_cfg → my_cfg → link_cfg)
4. Helpers                   (crc16_generator, error_expector)
5. Transaction items         (base_seq_item → dllp_seq_item → tlp_seq_item → if_seq_item)
6. Sequences                 (base_seq → feature_seq → init1_seq → init2_seq → tlp_seq → if_seq)
7. Agent sub-components      (cb_base → callbacks → tx_drv → monitors → state_mgr → states → agent)
8. Analysis components       (scoreboard → watchdog → coverage)
9. Environment               (pcie_dll_env)
10. Helpers (test-time)      (pcie_dll_report_catcher)
11. Tests                    (test_base → derived tests)
```

> **Never add new files outside this package.** Add a new `` `include `` to
> `pcie_dll_pkg.sv` at the correct position in the chain above.

### 4.3 Available UVM plusargs

| Plusarg | Effect |
|---|---|
| `+UVM_TESTNAME=<test_class>` | Select which test to run |
| `+UVM_VERBOSITY=UVM_LOW/MEDIUM/HIGH` | Global verbosity (default `UVM_LOW`) |
| `+UVM_TIMEOUT=<ns>` | Override the global UVM timeout |

---

## 5. VIP-to-VIP Wiring (B2B)

This is the **default configuration** — both `env_rc` and `env_ep` are connected through
`mock_phy_crossbar`, which routes each side's Tx directly to the other's Rx with zero
latency and no packet manipulation.

### 5.1 What `mock_phy_crossbar` does

```
rc_if.lp_data  → ep_if.pl_data      (RC transmits → EP receives)
ep_if.lp_data  → rc_if.pl_data      (EP transmits → RC receives)
rc_if.lp_valid → ep_if.pl_valid      (and all framing/control signals mirror symmetrically)
ep_if.pl_trdy  = rc_if.lp_irdy      (back-pressure echo)
pl_lnk_up      driven by IF driver via cb_drv clocking block
```

Static configuration tie-offs (set as parameters at elaboration):

| Parameter | Default | Meaning |
|---|---|---|
| `PL_LNK_CFG` | `3'b010` | x16 link width |
| `PL_SPEEDMODE` | `3'b101` | Gen5 |
| `PL_LNK_UP` | `1'b1` | Link immediately up (physical training bypassed) |
| `PL_INBAND_PRES` | `1'b1` | In-band presence detected |
| `PL_ERROR` | `1'b0` | No framing error injection at PHY level |

### 5.2 `tb_top.sv` wiring — exact steps

```systemverilog
// 1. Instantiate both LPIF interfaces, sharing clock and reset
pcie_lpif_if #(.NBYTES(64)) rc_if (.lclk(lclk), .rst_n(rst_n));
pcie_lpif_if #(.NBYTES(64)) ep_if (.lclk(lclk), .rst_n(rst_n));

// 2. Instantiate the B2B crossbar
mock_phy_crossbar #(
    .NBYTES        (64),
    .PL_LNK_CFG   (3'b010),
    .PL_SPEEDMODE  (3'b101),
    .PL_LNK_UP    (1'b1),
    .PL_INBAND_PRES(1'b1)
) u_crossbar (.intf_A(rc_if), .intf_B(ep_if));

// 3. Publish virtual interfaces to UVM config_db
//    Key names are FIXED — the agent looks for exactly these strings.
uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "rc_vif",  rc_if);
uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "ep_vif",  ep_if);
uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "lnk_vif", rc_if);
                                                                 // ↑ watchdog uses lnk_vif
                                                                 //   for clock edge access

// 4. Publish hardware parameters
uvm_config_db#(int)::set(uvm_root::get(), "*", "tb_nbytes",    64);
uvm_config_db#(pcie_link_width_e)::set(uvm_root::get(), "*", "tb_link_width", PCIE_LINK_X16);
uvm_config_db#(pcie_speed_mode_e)::set(uvm_root::get(), "*", "tb_speed_mode", PCIE_GEN5);
```

> **config_db key names are contract points** — `"rc_vif"`, `"ep_vif"`, `"lnk_vif"`,
> `"tb_nbytes"`, `"tb_link_width"`, `"tb_speed_mode"` must match exactly. Changing them
> requires updating `pcie_dll_agent.build_phase` and `pcie_dll_fc_watchdog.build_phase`.

### 5.3 Role assignment

The test base sets roles for each env scope:

```systemverilog
uvm_config_db#(pcie_dll_role_e)::set(this, "env_rc*", "role", ROLE_RC);
uvm_config_db#(pcie_dll_role_e)::set(this, "env_ep*", "role", ROLE_EP);
```

The agent reads the role and selects `rc_vif` or `ep_vif` accordingly — no other
role-dependent wiring is required.

---


---

## 6. VIP-to-RTL Wiring

When connecting to a real DUT (RTL implementation of the DLL), replace the
`mock_phy_crossbar` with direct port connections between the LPIF interface and the DUT.

### 6.1 What changes

| B2B setup | RTL-DUT setup |
|---|---|
| `mock_phy_crossbar` routes RC→EP, EP→RC | RTL DUT drives `pl_*` signals from its internal state machine |
| `pl_lnk_up` driven by IF driver clocking block | `pl_lnk_up` driven by DUT PHY model or another VIP |
| Static tie-offs on `pl_lnk_cfg`, `pl_speedmode` | Those signals come from the DUT |

### 6.2 Minimal `tb_top` for a single-side DUT

```systemverilog
// One LPIF interface connecting VIP (RC side) to the DUT (EP side)
pcie_lpif_if #(.NBYTES(64)) rc_if (.lclk(lclk), .rst_n(rst_n));

// DUT instance — its LPIF port bundle connects to rc_if
my_dut_dll u_dut (
    .lclk        (lclk),
    .rst_n       (rst_n),
    // DUT drives pl_* outputs (PHY→DLL direction from VIP's perspective)
    .pl_data     (rc_if.pl_data),
    .pl_valid    (rc_if.pl_valid),
    .pl_trdy     (rc_if.pl_trdy),
    .pl_dlpstart (rc_if.pl_dlpstart),
    .pl_dlpend   (rc_if.pl_dlpend),
    .pl_lnk_up   (rc_if.pl_lnk_up),
    // VIP drives lp_* outputs (DLL→PHY direction)
    .lp_data     (rc_if.lp_data),
    .lp_valid    (rc_if.lp_valid),
    .lp_irdy     (rc_if.lp_irdy),
    .lp_dlpstart (rc_if.lp_dlpstart),
    .lp_dlpend   (rc_if.lp_dlpend)
);

// Publish the single VIF; only env_rc is instantiated in a single-side test
uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "rc_vif",  rc_if);
uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "lnk_vif", rc_if);
```

> In single-side mode, only instantiate `env_rc`. Set its role to `ROLE_RC` and skip
> `env_ep` creation in the test's `build_phase`. The scoreboard's symmetry checks
> (`ASYMMETRIC_ACTIVE`) should be disabled or scoped to the single side via a config knob.

### 6.3 Key signal direction rules

| Signal prefix | Driven by | Sampled by |
|---|---|---|
| `lp_*` | **VIP** (via `cb_drv` clocking block in `pcie_dll_tx_drv`) | DUT + Tx monitor |
| `pl_*` | **DUT** (or mock crossbar in B2B) | VIP Rx monitor |
| `pl_lnk_up` | **DUT** PHY (or IF driver in B2B) | State manager, all state classes |

> **Critical**: `pl_lnk_up` is driven through `cb_drv` clocking block in the B2B setup.
> In VIP-to-RTL, the DUT drives it — remove `pl_lnk_up` from the `output` list of `cb_drv`
> in `pcie_lpif_if.sv` or leave it floating and let the DUT's net override it.

---

## 7. Configuration Objects

There are three config objects per side. The test creates and owns all of them.

### 7.1 `pcie_dll_env_cfg` — Static per-side config

Set in `build_phase` **before** `super.build_phase()` calls are complete. These values
are read once at startup and never mutated during the run.

**Hardware parameters** (auto-populated from `tb_top` via `config_db`, override if needed):

```systemverilog
cfg_rc.nbytes      = 64;           // bytes per clock cycle (x16 Gen5 = 64)
cfg_rc.link_width  = PCIE_LINK_X16;
cfg_rc.speed_mode  = PCIE_GEN5;
```

**Protocol knobs**:

```systemverilog
cfg_rc.scaled_fc_supported = 1'b1;  // enables DL_FEATURE_EXCH state
                                     // 0 = skip directly to DL_INIT_FC1
```

**Initial FC credit tables** (indexed by `pcie_fc_type_e`: `FC_P`, `FC_NP`, `FC_CPL`):

```systemverilog
cfg_rc.init_fc_hdr[FC_P]    = 8'h20;   // 32 Posted header credits
cfg_rc.init_fc_data[FC_P]   = 12'h100; // 256 Posted data credits
cfg_rc.init_fc_hdr[FC_NP]   = 8'h20;
cfg_rc.init_fc_data[FC_NP]  = 12'h100;
cfg_rc.init_fc_hdr[FC_CPL]  = 8'h20;
cfg_rc.init_fc_data[FC_CPL] = 12'h100;
// Set all to 0 for zero-credits test (spec-legal)
```

**Traffic behaviour knobs** (default all `0` / disabled):

```systemverilog
cfg_rc.enable_errors    = 1'b1;  // activates CRC / invalid-DLLP / invalid-VC callbacks
cfg_rc.corrupted_initfc = 1'b1;  // seq item constraint allows disordered InitFC types
cfg_rc.delayed_packets  = 1'b1;  // seq item delay field picks values up to ~35000 cycles
cfg_rc.req_count        = 1000;  // number of DLLP iterations per sequence
```

**Error injection weights** (probability = 1/weight; lower = more frequent):

```systemverilog
cfg_rc.crc_error_weight        = 3;   // 1-in-3 chance of CRC corruption per packet
cfg_rc.invalid_dllp_weight     = 3;   // 1-in-3 chance of invalid DLLP type
cfg_rc.invalid_VC_weight       = 2;   // 1-in-2 chance of wrong VC
cfg_rc.corrupted_initfc_weight = 10;  // 1-in-10 chance of disordered InitFC
cfg_rc.max_weight              = 100; // upper bound for corrupted_initfc_weight validation
```

**Timing**:

```systemverilog
cfg_rc.init_rx_interval_cycles = 34_000; // 34 µs at 1 GHz; used by watchdog
```

**Publishing to config_db** (done automatically by `test_base` — do not repeat):

```systemverilog
pcie_dll_env_cfg::set_cfg(this, "env_rc*", cfg_rc); // sets key "cfg" under env_rc scope
pcie_dll_env_cfg::set_cfg(this, "env_ep*", cfg_ep);
```

### 7.2 `pcie_dll_my_cfg` — Runtime FSM state (read-only from the test)

Created by `pcie_dll_env` — do **not** create in the test. Access via the env handle:

```systemverilog
// Wait for a side to reach a specific state:
wait(env_rc.my_cfg.dlsm_state == DL_ACTIVE);

// Read FC counters:
$display("FC1 counter: %0d", env_rc.my_cfg.counter_fc1); // 0–3
$display("FC2 counter: %0d", env_rc.my_cfg.counter_fc2); // 0–3

// Gate flags (set by FSM, checked by scoreboard):
// env_rc.my_cfg.fi1_set == 1  → all InitFC1 received
// env_rc.my_cfg.fi2_set == 1  → all InitFC2 received
```

### 7.3 `pcie_dll_link_cfg` — Shared link-up/reset events

Shared between both envs. Accessed via UVM config_db or directly through the test handle:

```systemverilog
// Provided events:
lnk_cfg.pl_asserted   // triggered when pl_lnk_up goes 1
lnk_cfg.pl_realesed   // triggered when pl_lnk_up goes 0  (note: field name as-is)
lnk_cfg.reset_asserted
lnk_cfg.reset_released

// Poll current status:
if (lnk_cfg.pl_up) ...
```

---

## 8. Writing a New Test

### 8.1 Minimal clean test (no errors)

```systemverilog
class my_new_test extends pcie_dll_test_base;
    `uvm_component_utils(my_new_test)

    function new(string name = "my_new_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ----------------------------------------------------------------
    // build_phase: call super FIRST, then override cfg fields.
    // super.build_phase creates cfg_rc / cfg_ep and the environments.
    // ----------------------------------------------------------------
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Set FC credits (both sides must advertise the same structure)
        cfg_rc.init_fc_hdr[FC_P]   = 8'h20;  cfg_rc.init_fc_data[FC_P]   = 12'h100;
        cfg_rc.init_fc_hdr[FC_NP]  = 8'h20;  cfg_rc.init_fc_data[FC_NP]  = 12'h100;
        cfg_rc.init_fc_hdr[FC_CPL] = 8'h20;  cfg_rc.init_fc_data[FC_CPL] = 12'h100;

        cfg_ep.init_fc_hdr[FC_P]   = 8'h40;  cfg_ep.init_fc_data[FC_P]   = 12'h200;
        cfg_ep.init_fc_hdr[FC_NP]  = 8'h40;  cfg_ep.init_fc_data[FC_NP]  = 12'h200;
        cfg_ep.init_fc_hdr[FC_CPL] = 8'h40;  cfg_ep.init_fc_data[FC_CPL] = 12'h200;

        cfg_rc.scaled_fc_supported = 1'b1; // enable Feature Exchange
        cfg_ep.scaled_fc_supported = 1'b1;

        cfg_rc.req_count = 500;
        cfg_ep.req_count = 500;
    endfunction

    // ----------------------------------------------------------------
    // run_phase: raise objection → wait for DL_ACTIVE → drop objection.
    // ----------------------------------------------------------------
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.raise_objection(this, "Running my_new_test");

        // Wait for both sides to reach DL_ACTIVE in parallel
        fork
            wait(env_rc.my_cfg.dlsm_state == DL_ACTIVE);
            wait(env_ep.my_cfg.dlsm_state == DL_ACTIVE);
        join

        `uvm_info("TEST", "Both sides reached DL_ACTIVE. Test PASSED.", UVM_LOW)
        #10ns; // small drain time
        phase.drop_objection(this, "Done");
    endtask

endclass : my_new_test
```

Then include it in `pcie_dll_pkg.sv` **after** `test_base.sv`:

```systemverilog
`include "tests/my_new_test.sv"
```

Run it with:

```
+UVM_TESTNAME=my_new_test
```

### 8.2 Multi-iteration test pattern

Most existing tests loop the bring-up cycle to stress the FSM reset path. After each
iteration, `pcie_dll_if_seq` drops the link and the FSM resets to `DL_INACTIVE`:

```systemverilog
task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    repeat (5) begin
        // Wait for both sides to complete bring-up
        fork
            wait(env_rc.my_cfg.dlsm_state == DL_ACTIVE);
            wait(env_ep.my_cfg.dlsm_state == DL_ACTIVE);
        join

        `uvm_info("TEST", "DL_ACTIVE reached — resetting link.", UVM_LOW)

        // Drop the link; FSM returns to DL_INACTIVE
        if_seq = pcie_dll_if_seq::type_id::create("if_seq");
        if_seq.start(if_agent.if_sqr);

        #5ns; // allow INACTIVE state to settle
    end

    phase.drop_objection(this);
endtask
```

> `if_agent` is declared in `pcie_dll_test_base` and is always available.
> `pcie_dll_if_seq` always drives `drop_link=1` — it is a link teardown sequence.

### 8.3 `start_of_simulation_phase` — report catcher registration

`pcie_dll_test_base.start_of_simulation_phase` automatically creates and registers a
`pcie_dll_report_catcher`. If your test has no expected errors, do nothing — any
`UVM_ERROR` will propagate normally and fail the simulation.

If your test deliberately triggers errors, add tags **after** calling `super`:

```systemverilog
function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase); // creates and registers the catcher
    catcher.add_expected_tag("ILLEGAL_DLLP");
    catcher.add_expected_tag("PKT_DROP");
endfunction
```

See Section 11 for the full tag reference.

---

---

## 9. Error Injection via Callbacks

Three pre-built Tx driver callbacks live in `vip/agents/`. All three gate on
`dllp.enable_errors` — set `cfg.enable_errors = 1'b1` to activate them.

| Callback class | What it mutates | Controlled by |
|---|---|---|
| `pcie_dll_tx_drv_cb_crc` | Zeros the 16-bit CRC field (`dllp[47:32]`) | `crc_error_weight` |
| `pcie_dll_tx_drv_cb_invalid_dllp` | Replaces the full DLLP with type=0/payload=0 | `invalid_dllp_weight` |
| `pcie_dll_tx_drv_cb_vc` | Sets VC bits `[2:0]` to `3'b111` (non-zero VC) | `invalid_VC_weight` |

### 9.1 Registering callbacks in a test

```systemverilog
// build_phase — create handles
pcie_dll_tx_drv_cb_crc pcie_dll_tx_drv_cb_crc_env_rc =
    pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_rc");

// connect_phase — register against each driver
uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(
    env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_rc);
```

Repeat for `env_ep` and for each callback type needed. See `test_base_error_injected.sv`
for a complete working example.

### 9.2 Writing a custom callback

```systemverilog
class my_cb extends pcie_dll_tx_drv_cb_base;
    `uvm_object_utils(my_cb)

    virtual function bit pre_transmit(pcie_dll_base_seq_item req = null, bit drop = 1'b0);
        pcie_dll_dllp_seq_item dllp;
        if (!$cast(dllp, req)) return 1'b0;

        if (dllp.enable_errors) begin
            // mutate dllp fields here
            dllp.dllp[31:24] = 8'hFF; // corrupt a byte
            return 1'b1;              // return 1 = item was modified
        end
        return 1'b0;
    endfunction
endclass
```

`post_transmit` is also available if you need to observe after the packet was sent.
The callback **must** cast `req` to `pcie_dll_dllp_seq_item` — the driver passes a
base handle.

---

## 10. Link-Control Sequences

`pcie_dll_if_seq` is the only link-level sequence. It always drives `drop_link=1`,
which causes the IF driver to deassert `pl_lnk_up` for a randomised number of cycles.

```systemverilog
pcie_dll_if_seq if_seq;

// Fire from the test's run_phase:
if_seq = pcie_dll_if_seq::type_id::create("if_seq");
if_seq.start(if_agent.if_sqr);  // blocks until the driver completes
```

`pcie_dll_if_seq_item` has two randomisable fields:

| Field | Type | Effect |
|---|---|---|
| `drop_link` | `rand bit` | Constrained to `1` by `pcie_dll_if_seq`; causes link teardown |
| `cycles_num` | `rand int unsigned` | Number of cycles to hold link down (randomised by solver) |

When `drop_link=1` is processed by `pcie_dll_if_drv`, it drives `pl_lnk_up=0` through
`cb_drv`, triggering the `pl_realesed` event in `lnk_cfg`. Every active state class
monitors this event on **Thread 3** and immediately exits back to `DL_INACTIVE`.

---

## 11. Report Catcher — Tag Reference

`pcie_dll_test_base` registers a `pcie_dll_report_catcher` globally. Only add expected
tags for errors your test intentionally triggers. **Never demote watchdog or scoreboard
errors in a clean test.**

### 11.1 Scoreboard tags (ID = `"SCOREBOARD"`)

| Tag string | Triggered when |
|---|---|
| `"ILLEGAL_DLLP"` | Wrong DLLP type for current FSM state |
| `"ILLEGAL_TLP"` | TLP received while link not active |
| `"VIRTUAL_CHANNEL"` | InitFC DLLP with non-zero VC bits |
| `"CREDIT_MISMATCH"` | Received credits differ from stored partner values |
| `"PKT_DROP"` | FSM packet counter did not increment (packet dropped) |
| `"INITFC1_OUT_OF_ORDER"` | InitFC1 sequence P→NP→Cpl violated |
| `"INITFC2_OUT_OF_ORDER"` | InitFC2 sequence P→NP→Cpl violated |
| `"FEATURE_RESERVED_ZERO"` | Feature DLLP reserved bits `[22:1]` non-zero |
| `"FEATURE_ACK_HANDSHAKE"` | Partner ack seen before we sent any Feature DLLP |

### 11.2 Watchdog tags (ID = `"WDOG"`)

| Tag string | Triggered when |
|---|---|
| `"FEAT_TIMEOUT"` | No Feature DLLP received within 34 µs in `DL_FEATURE_EXCH` |
| `"FC1_TIMEOUT"` | No InitFC1_P received within 34 µs in `DL_INIT_FC1` |
| `"FC2_TIMEOUT"` | No InitFC2_P received within 34 µs in `DL_INIT_FC2` |

### 11.3 Per-test expected tags (existing tests)

| Test | Tags registered |
|---|---|
| `test_base_error_injected` | `ILLEGAL_DLLP`, `INITFC1_OUT_OF_ORDER`, `INITFC2_OUT_OF_ORDER`, `VIRTUAL_CHANNEL`, `PKT_DROP` |
| `test_base_corrupted_initfc` | `INITFC1_OUT_OF_ORDER`, `INITFC2_OUT_OF_ORDER`, `PKT_DROP` |
| `test_base_delayed_packets` | `FEAT_TIMEOUT`, `FC1_TIMEOUT`, `FC2_TIMEOUT` |
| All other tests | *(none)* |

---

## 12. Analysis Components Reference

### Scoreboard (`pcie_dll_scoreboard`)

Receives three TLM streams per env:

| Port | Source | What it checks |
|---|---|---|
| `rx_export` | `agent_rx_ap` | Incoming DLLP validity, credit tracking, ordering |
| `tx_export` | `agent_tx_ap` | Traffic isolation (no TLP before DL_ACTIVE) |
| `state_export` | `state_ap` | State transition legality, gate flag checks |
| `counter_export` | `agent_counter_ap` | FC1/FC2 packet counters |

All protocol checks are delegated to `pcie_dll_common_checks` static methods and
`error_expector` for error classification.

### FC Watchdog (`pcie_dll_fc_watchdog`)

One per env. Receives `rx_export` and `state_export`. Internally forks three
`forever` threads (Feature / FC1 / FC2), each running a 3-way `fork/join_any`:
timer thread, reset thread (waits for next expected DLLP), and exit thread.

Timeout fires `UVM_ERROR` with ID `"WDOG"` and triggers the matching
`uvm_event` in the global event pool so coverage can sample the scenario.

---

## 13. Coverage Collection

Two `pcie_dll_coverage` instances per env: `cov_tx` (Tx path) and `cov_rx` (Rx path).
Path type is set via `uvm_config_db` before instantiation — this controls which
covergroups are enabled:

| Covergroup | Active in |
|---|---|
| `cg_dllp_type` | Both paths |
| `cg_state_transitions` | Both paths |
| `cg_fc_credits` | Rx path only |
| `cg_active_status` | Tx path only |
| `cg_watchdog` | Rx path only (samples watchdog timeout events) |

### Generating a coverage report (Questa)

```tcl
# Save during simulation (in run.do or vsim -do):
coverage save my_test.ucdb

# Generate text report:
vcover report -details -comments my_test.ucdb > coverage_report.txt

# Merge across multiple runs:
vcover merge merged.ucdb run1.ucdb run2.ucdb ...
vcover report merged.ucdb
```

---

## 14. Common Pitfalls

| Problem | Cause | Fix |
|---|---|---|
| `NOVIF` fatal at build | `rc_vif` / `ep_vif` / `lnk_vif` not set in `tb_top` | Ensure all three `uvm_config_db::set` calls exist with exact key names |
| `NOCFG` fatal at build | `pcie_dll_env_cfg::set_cfg` not called, or scope path wrong | Confirm scopes `"env_rc*"` / `"env_ep*"` match env instance names |
| FSM never leaves `DL_INACTIVE` | `pl_lnk_up` never asserted | In B2B mode, crossbar ties it to `1'b1`. In RTL mode, DUT must assert it |
| FSM stuck in `DL_FEATURE_EXCH` | Both sides have `scaled_fc_supported=0` but Feature state was entered | Check `pcie_dll_env_cfg.scaled_fc_supported` — both sides must agree |
| Watchdog fires unexpectedly | `init_rx_interval_cycles` too small, or simulation time-scale mismatch | Default is 34 000 cycles at 1 GHz. Adjust if your clock period differs |
| Unexpected `CREDIT_MISMATCH` | RC and EP credit arrays set inconsistently | RC's `init_fc_hdr[FC_P]` is what EP stores as "partner credits"; ensure cross-side values are what you intend |
| Callback not firing | `enable_errors` not set to `1` on the cfg before simulation starts | Set `cfg_rc.enable_errors = 1'b1` in `build_phase` **after** `super.build_phase` |
| New file not compiling | File added to disk but not to `pcie_dll_pkg.sv` | Add `` `include `` in the correct position in the dependency chain (see Section 4.2) |
| `UVM_ERROR` demoted in clean test | `catcher.add_expected_tag` called in base | Only call from derived tests; base test registers an empty catcher |

