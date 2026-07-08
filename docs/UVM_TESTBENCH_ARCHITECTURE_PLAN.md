# UVM Testbench Architecture Plan — PCIe Gen5 DLL VIP

> **Baseline**: PCIe Gen5 DLL in variable-length packet (non-FLIT) mode.
> **Status**: Detailed component responsibility plan based on actual testbench architecture.
> **Scope**: DLCMSM bring-up — DL Feature Exchange + FC Initialization for VC0.

---

## 1. Top-Level Testbench Architecture

A **symmetric dual-environment** design: one `pcie_dll_env` class instantiated twice
(`env_rc` / `env_ep`) with different roles. Configuration is per-side. The LPIF mock-PHY
provides zero-latency B2B loopback.

![VIP UVM Architecture](PCIE_DLL_VIP_UVM_ARCH.png)

**Timescale / Clock**: `1ns/1ps`, 1 GHz `lclk` (500 ps period). Reset deasserted after
10 clock cycles.

---

## 2. Test Classes

### Base: `pcie_dll_test_base` (`uvm_test`)

**File**: `vip/tests/test_base.sv`

**Responsibilities**:
- Creates two separate `pcie_dll_env_cfg` objects (`cfg_rc`, `cfg_ep`) and calls `set_defaults()` on each.
- Reads TB-level parameters from `uvm_config_db` (`tb_nbytes`, `tb_link_width`, `tb_speed_mode`) published by `tb_top`.
- Creates a shared `pcie_dll_link_cfg` object and publishes it to all components.
- Sets `ROLE_RC` / `ROLE_EP` per-environment via `uvm_config_db`.
- Instantiates `env_rc`, `env_ep`, and the link-level `pcie_dll_if_agent`.
- `start_of_simulation_phase`: creates and globally registers a `pcie_dll_report_catcher`; derived tests call `catcher.add_expected_tag()` on top.
- `final_phase`: calls `catcher.report()` to print the expected-error demotion summary.
- `run_phase()` is empty — each derived test implements its scenario.


### Derived Tests (all in `vip/tests/`)

| Class | Scenario |
|---|---|
| `test_base_with_feature` | Normal bring-up: DL_FEATURE_EXCH → DL_INIT_FC1 → DL_INIT_FC2 → DL_ACTIVE. Registers all three Tx driver callbacks. Runs 4 repetitions. |
| `test_base_without_feature` | Skips feature exchange; goes directly DL_INACTIVE → DL_INIT_FC1. |
| `test_base_corrupted_initfc` | Sets `cfg.corrupted_initfc=1`; exercises disordered / repeated InitFC packets. |
| `test_base_error_injected` | Sets `cfg.enable_errors=1`; CRC corruption and invalid-DLLP injection via callbacks. |
| `test_base_delayed_packets` | Sets `cfg.delayed_packets=1`; back-pressure delay distribution on DLLP transmission. |
| `test_base_zero_credits` | Configures zero initial credits (hdr/data = 0) for FC advertisement. |
| `test_base_drop_link` | **Link-resilience test.** Randomises `link_drop_target_state` (any `pcie_dlcmsm_state_e` value), waits for both RC and EP to reach that state, then fires `pcie_dll_if_seq` to drop `pl_lnk_up`. Repeats 10 times. Verifies that every state class handles an in-flight link-drop by transitioning back to `DL_INACTIVE` via `pl_realesed` event. No error injection — a clean pass validates FSM resilience across all states. |

**Default test** (hardcoded in `tb_top.sv`): `run_test("test_base_with_feature")`.

---

## 3. Configuration Objects

### 3.1 `pcie_dll_env_cfg` — Shared Per-Side Config

**File**: `vip/env/pcie_dll_env_cfg.sv`

Hardware-fixed parameters (set from `tb_top`):
- `link_width` (enum `pcie_link_width_e`; default `PCIE_LINK_X16`)
- `speed_mode` (enum `pcie_speed_mode_e`; default `PCIE_GEN5`)
- `nbytes` (int; default `64` for x16 @ 1 GHz)

Protocol feature enables:
- `scaled_fc_supported` (`rand bit`; controls Feature DLLP `feature_support[0]`)

Traffic-behaviour knobs:
- `enable_errors` — gates error-injection callbacks
- `corrupted_initfc` — enables disordered/repeated InitFC packets
- `delayed_packets` — enables per-DLLP cycle delay field
- `req_count` (`rand int unsigned`) — sequence iteration count
- `corrupted_initfc_weight` (int unsigned) — weight for corrupted INITFC state (normal, repeated, and disorder packets)
- `crc_error_weight` (int unsigned) — weight for CRC error in DLLPs
- `invalid_dllp_weight` (int unsigned) — weight for invalid DLLPs
- `invalid_VC_weight` (int unsigned) — weight for invalid Virtual Channel (VC)
- `max_weight` (int unsigned) — maximum weight limit reference (default 100)

Initial FC credit arrays (indexed by `pcie_fc_type_e`):
- `init_fc_hdr_scale[FC_P/NP/CPL]` (2-bit scale)
- `init_fc_hdr[FC_P/NP/CPL]` (8-bit header credits)
- `init_fc_data_scale[FC_P/NP/CPL]` (2-bit scale)
- `init_fc_data[FC_P/NP/CPL]` (12-bit data credits)

Timing:
- `init_rx_interval_cycles` — 34 µs interval in clock cycles (default `34_000` at 1 GHz)

Helpers: `set_cfg()` / `get_cfg()` static methods for `uvm_config_db` access;
`validate()` for constraint checking; `summary()` for log output.

### 3.2 `pcie_dll_partner_cfg` — Runtime Partner State

**File**: `vip/env/pcie_dll_partner_cfg.sv`

Stores credits captured from the link partner's InitFC DLLPs:
- `partner_credits[pcie_fc_type_e]` — associative array of `pcie_fc_credits_values_s` structs
  (each has `hdr_limit`, `data_limit`, `hdr_scale`, `data_scale`, `absolute_hdr_limit`, `absolute_data_limit`)
- `partner_feature_valid` — asserted once first Feature DLLP received
- `partner_feature_support` — 23-bit feature field from partner's Feature DLLP

Key methods: `set_credits_value()` (called by InitFC1 state), `calculate_absolute_credits()`,
`reset()`, `view_credits()`.

### 3.3 `pcie_dll_my_cfg` — Local FSM Tracking State

**File**: `vip/env/pcie_dll_my_cfg.sv`

- `dlsm_state` — current `pcie_dlcmsm_state_e` (read by test, coverage, scoreboard)
- `counter_fc1` / `counter_fc2` — in-order receipt counters (0–3)
- `fi1_set` / `fi2_set` — gate flags checked by scoreboard before state transitions
- `reset()` / `view_state()` helpers

### 3.4 `pcie_dll_link_cfg` — Shared Link Status

**File**: `vip/env/pcie_dll_link_cfg.sv`

- `pl_up` — current link-up status (sampled by states, checked by scoreboard)
- `is_in_reset` — reset status
- UVM events: `pl_asserted`, `pl_realesed`, `reset_asserted`, `reset_released`

---

## 4. LPIF Interface & Mock-PHY

### 4.1 `pcie_lpif_if` — LPIF SystemVerilog Interface

**File**: `tb/pcie_lpif_if.sv` | Parameter: `NBYTES` (default 64)

**Tx Path (DLL → PHY) — `lp_*` signals**:

| Signal | Width | Description |
|---|---|---|
| `lp_data` | `(NBYTES*8)-1:0` | Data payload |
| `lp_valid` | `NBYTES-1:0` | Per-byte valid |
| `lp_irdy` | `1` | DLL ready to send |
| `lp_state_req` | `4` | Power/link state request |
| `lp_tlpstart` | `NBYTES-1:0` | TLP start byte-lane |
| `lp_tlpend` | `NBYTES-1:0` | TLP end byte-lane |
| `lp_dlpstart` | `NBYTES-1:0` | DLLP start byte-lane |
| `lp_dlpend` | `NBYTES-1:0` | DLLP end byte-lane |

**Rx Path (PHY → DLL) — `pl_*` signals**: mirror of above plus `pl_trdy`, `pl_lnk_up`,
`pl_lnk_cfg`, `pl_speedmode`, `pl_inband_pres`, `pl_error`, `pl_cerror`, `pl_tlpedb`.

**Clocking blocks**:
- `cb_drv` — `default output #1step`; drives all `lp_*` outputs + `pl_lnk_up`
- `cb_mon_tx` — `default input #1step`; samples `lp_*` + `pl_trdy`, `pl_lnk_up`
- `cb_mon_rx` — `default input #1step`; samples `pl_*` including `pl_tlpedb`

**SVA Properties** — 8 `assert property` blocks, all instantiated directly in the interface body:

| Label | Property | `disable iff` condition | What it catches |
|---|---|---|---|
| `CHK_VALID_IRDY` | `(\|lp_valid) \|-> lp_irdy` | `!rst_n \|\| !pl_lnk_up` | `lp_valid` strobed while DLL not ready |
| `CHK_TLP_BOUNDS` | `(\|tlpstart && \|tlpend) \|-> tlpstart <= tlpend` | `!rst_n \|\| !pl_lnk_up` | Negative-length TLP frame |
| `CHK_DLP_BOUNDS` | `(\|dlpstart && \|dlpend) \|-> dlpstart <= dlpend` | `!rst_n \|\| !pl_lnk_up` | Negative-length DLLP frame |
| `CHK_VALID_BOUNDS` | `lp_valid` bits fully within start/end byte-lane range | `!rst_n \|\| !pl_lnk_up` | Valid bits set outside packet window |
| `CHK_ONEHOT_FRAMING` | `$onehot0` on all four framing vectors | `!rst_n \|\| !pl_lnk_up` | Two simultaneous start/end bits in one cycle |
| `CHK_TLP_DLLP_COLLISION` | No overlapping byte-lanes between TLP and DLLP framing | `!rst_n \|\| !pl_lnk_up` | Interleaved TLP/DLLP frames on the same byte lanes |
| `CHK_LNK_DOWN_FLUSH` | `(!pl_lnk_up) \|-> irdy==0 && valid==0 && data==0 && all framing==0` | `!rst_n` | DLL drives traffic after link teardown |
| `CHK_NO_X_STATES` | `!$isunknown({irdy, trdy, valid, lnk_up, framing vectors})` | `!rst_n` | Any X/Z on critical control or framing signals |

### 4.2 `mock_phy_crossbar` — B2B Loopback

**File**: `rtl/mock_phy_crossbar.sv`

Parameters: `NBYTES=64`, `PL_LNK_CFG=3'b010` (x16), `PL_SPEEDMODE=3'b101` (Gen5),
`PL_LNK_UP=1'b1`, `PL_INBAND_PRES=1'b1`, `PL_ERROR=1'b0`, `PL_CERROR=1'b0`, `PL_TLPEDB=0`.

Routing:
- `intf_A.lp_*` → `intf_B.pl_*` (RC Tx → EP Rx)
- `intf_B.lp_*` → `intf_A.pl_*` (EP Tx → RC Rx)
- `intf_B.pl_trdy = intf_A.lp_irdy` and vice versa
- `pl_state_sts = lp_state_req` (immediate echo per side)
- `intf_B.pl_lnk_up = intf_A.pl_lnk_up` (driven via `cb_drv` clocking block by IF driver)

Static tie-offs (compile-time parameters): `pl_lnk_cfg`, `pl_speedmode`, `pl_inband_pres`,
`pl_error`, `pl_cerror`.

### 4.3 `tb_top` — Top-Level Module

**File**: `tb/tb_top.sv` | `timescale 1ns/1ps`

- `localparam NBYTES = 64`
- Instantiates `rc_if` and `ep_if` (`pcie_lpif_if #(.NBYTES(64))`)
- Instantiates `u_crossbar` (`mock_phy_crossbar`)
- Publishes to `uvm_config_db`: `tb_nbytes`, `tb_link_width`, `tb_speed_mode`, `rc_vif`, `ep_vif`, `lnk_vif`
- Calls `run_test("test_base_with_feature")`

---

## 5. Environment & Agent Architecture

### 5.1 `pcie_dll_env` — Unified Environment

**File**: `vip/env/pcie_dll_env.sv`

Single class; role resolved from `uvm_config_db` in `build_phase`.

**Subcomponents instantiated**:
- `pcie_dll_agent agent` — contains all active VIP components
- `pcie_dll_scoreboard scoreboard`
- `pcie_dll_fc_watchdog fc_watchdog`
- `pcie_dll_coverage cov_tx` — samples Tx analysis port
- `pcie_dll_coverage cov_rx` — samples Rx analysis port
- `pcie_dll_partner_cfg partner_cfg` — published to `uvm_config_db` for all children
- `pcie_dll_my_cfg my_cfg` — published to `uvm_config_db` for all children

**`connect_phase` TLM connections**:
```
agent.agent_tx_ap    → cov_tx.analysis_export
agent.agent_rx_ap    → cov_rx.analysis_export
agent.state_ap       → scoreboard.state_export
agent.agent_rx_ap    → scoreboard.rx_export
agent.agent_tx_ap    → scoreboard.tx_export
agent.agent_counter_ap → scoreboard.counter_export
agent.state_ap       → fc_watchdog.state_export
agent.agent_rx_ap    → fc_watchdog.rx_export
```

### 5.2 `pcie_dll_agent` — Active Agent

**File**: `vip/agents/pcie_dll_agent.sv`

Resolves `role` and selects `rc_vif` or `ep_vif` from `uvm_config_db`.

**Subcomponents**:
- `pcie_dll_state_mgr state_mgr`
- `pcie_dll_tx_mon tx_mon`
- `pcie_dll_rx_mon rx_mon`
- `pcie_dll_seqr sqr`
- `pcie_dll_tx_drv tx_drv`

**Analysis ports exposed upward**:
- `state_ap` (`pcie_dlcmsm_state_e`) — from `state_mgr`
- `agent_tx_ap` (`pcie_dll_base_seq_item`) — from `tx_mon`
- `agent_rx_ap` (`pcie_dll_base_seq_item`) — from `rx_mon`
- `agent_counter_ap` (`pcie_fc_pkt_counters_s`) — from `state_mgr`

**`connect_phase`**:
```
rx_mon.mon_rx_ap  → state_mgr.dllp_export   (feeds FSM)
tx_drv.seq_item_port → sqr.seq_item_export
state_mgr.state_ap → agent.state_ap
tx_mon.mon_tx_ap  → agent.agent_tx_ap
rx_mon.mon_rx_ap  → agent.agent_rx_ap
state_mgr.fc_pkt_counter_ap → agent.agent_counter_ap
```

---

## 6. Tx Driver — `pcie_dll_tx_drv`

**File**: `vip/agents/pcie_dll_tx_drv.sv` | Extends `uvm_driver #(pcie_dll_base_seq_item)`

**Role**: Converts transaction-level `pcie_dll_base_seq_item` (DLLP or TLP) into cycle-accurate
LPIF signal drives via the `cb_drv` clocking block.

**Run-phase behaviour**:
1. Initialises all `lp_*` signals to idle on `cb_drv` at simulation start.
2. Every clock, resets all framing/valid/data signals to 0.
3. Waits for `rst_n && pl_lnk_up` before pulling from sequencer.
4. Calls `seq_item_port.get_next_item(req)` — blocking.
5. Casts `req` to `pcie_dll_dllp_seq_item` or `pcie_dll_tlp_seq_item`.
6. For DLLPs: optionally delays `dllp_txn.delay` cycles (if `cfg.delayed_packets`), fires `pre_transmit` callbacks, then drives:
   - `lp_irdy = 1`, `lp_data[47:0] = dllp`, `lp_valid = 6'b111_111`
   - `lp_dlpstart = 1<<0`, `lp_dlpend = 1<<5` (DLLP always occupies bytes 0–5)
7. For TLPs: drives `lp_irdy=1`, `lp_data[127:0] = tlp`, `lp_valid = 16'hFFFF`,
   `lp_tlpstart = 1<<0`, `lp_tlpend = 1<<15`.
8. Calls `seq_item_port.item_done()`.

### 6.1 Tx Driver Callback Infrastructure

Base class: `pcie_dll_tx_drv_cb_base` (`vip/agents/pcie_dll_tx_drv_cb_base.sv`)
- Declares virtual `pre_transmit(pcie_dll_dllp_seq_item item)` — no-op default.
- Registered via `` `uvm_register_cb(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_base) ``.
- Invoked using the `` `pcie_do_callbacks_one_hot `` macro (`pcie_dll_tx_drv_cb_macro.svh`).

**Concrete callbacks** (all in `vip/agents/`):

| Class | File | Effect |
|---|---|---|
| `pcie_dll_tx_drv_cb_crc` | `pcie_dll_tx_drv_cb_crc.sv` | Corrupts the 16-bit CRC field of the outgoing DLLP (gated by `item.enable_errors`) |
| `pcie_dll_tx_drv_cb_invalid_dllp` | `pcie_dll_tx_drv_cb_invalid_dllp.sv` | Replaces DLLP type with an illegal value for the current state (gated by `item.corrupted_initfc`) |
| `pcie_dll_tx_drv_cb_vc` | `pcie_dll_tx_drv_cb_vc.sv` | Sets a non-zero VC field in the DLLP byte to inject VC violations |

Tests register callbacks via `uvm_callbacks#(pcie_dll_tx_drv, ...)::add(env.agent.tx_drv, cb)`.

---

## 7. Monitors

### 7.1 Tx Snoop Monitor — `pcie_dll_tx_mon`

**File**: `vip/agents/pcie_dll_tx_mon.sv` | Extends `uvm_monitor`

Samples `cb_mon_tx` every clock when `rst_n && pl_lnk_up`.

**DLLP detection**: `lp_dlpstart < lp_dlpend` AND `lp_irdy==1` AND `lp_valid==6'b111_111` AND `pl_trdy==1`
→ unpacks `lp_data[47:0]` into `pcie_dll_dllp_seq_item`, publishes on `mon_tx_ap`.

**TLP detection**: `lp_tlpstart < lp_tlpend` AND `lp_irdy==1` AND `lp_valid==16'hFFFF` AND `pl_trdy==1`
→ captures `lp_data[127:0]` into `pcie_dll_tlp_seq_item`, publishes on `mon_tx_ap`.

### 7.2 Rx Monitor — `pcie_dll_rx_mon`

**File**: `vip/agents/pcie_dll_rx_mon.sv` | Extends `uvm_monitor`

Samples `cb_mon_rx` every clock when `rst_n && pl_lnk_up`.

**DLLP detection**: `pl_dlpstart < pl_dlpend` AND `pl_valid==6'b111_111`
→ unpacks `pl_data[47:0]` into `pcie_dll_dllp_seq_item` (CRC decoded by `unpack()`),
publishes on `mon_rx_ap` — connected to both `state_mgr.dllp_export` and `agent.agent_rx_ap`.

**TLP detection**: `pl_tlpstart < pl_tlpend` AND `pl_valid==16'hFFFF`
→ captures `pl_data[127:0]` into `pcie_dll_tlp_seq_item`, publishes on `mon_rx_ap`.

> Note: The Rx monitor does **not** filter on CRC before publishing. CRC checking is
> delegated to `error_expector` (used by coverage and scoreboard).

### 7.3 Interface-Level Monitor — `pcie_dll_if_mon`

**File**: `vip/agents/interface_agent/pcie_dll_if_mon.sv`

Monitors `lnk_vif` (tied to `rc_if`) for `pl_lnk_up` and `rst_n` transitions.
Publishes changes to `pcie_dll_link_cfg` events (`pl_asserted`, `pl_realesed`,
`reset_asserted`, `reset_released`) so states can react to link-down conditions.

---

## 8. State Manager & DLCMSM FSM

### 8.1 `pcie_dll_state_mgr`

**File**: `vip/agents/pcie_dll_state_mgr.sv` | Extends `uvm_component`

**Responsibilities**:
- Owns the current FSM state object (`pcie_dll_base_state current_state`).
- Receives all Rx-side packets from `rx_mon` via `dllp_export` (`uvm_analysis_imp`).
- Routes packets into `dllp_fifo` or `tlp_fifo` (`uvm_tlm_fifo`) for the active state to consume.
- Broadcasts state changes on `state_ap` (`uvm_analysis_port #(pcie_dlcmsm_state_e)`).
- Exposes `fc_pkt_counter_ap` to publish `pcie_fc_pkt_counters_s` after each counter update.
- Holds handles to `cfg`, `partner_cfg`, `my_cfg`, `lnk_cfg`, and `dllp_sequencer`.
- `run_phase()` enters `change_state(DL_INACTIVE)` to start the FSM.

**`change_state(new_state)` task**:
1. Uses `uvm_factory` to create the concrete state object by name (`pcie_dll_<ENUM_NAME>`).
2. Casts to `pcie_dll_base_state`.
3. Updates `my_cfg.dlsm_state` and broadcasts on `state_ap`.
4. Calls `current_state.start_state(this)` — blocks until state exits.

### 8.2 `pcie_dll_base_state` — State Base Class

**File**: `vip/agents/pcie_dll_base_state.sv` | Extends `uvm_object`

- Field: `pcie_dlcmsm_state_e next_state`
- Virtual task `start_state(pcie_dll_state_mgr manager)` — fatal if not overridden.
- Forward declaration of `pcie_dll_state_mgr` avoids circular dependency.

### 8.3 Concrete State Classes

#### `pcie_dll_DL_INACTIVE`
**File**: `vip/agents/pcie_dll_inactive_state.sv`

Waits for `lnk_cfg.pl_asserted` event. Transitions to `DL_FEATURE_EXCH` or `DL_INIT_FC1`
depending on `cfg.scaled_fc_supported` / test scenario.

#### `pcie_dll_DL_FEATURE_EXCH`
**File**: `vip/agents/pcie_dll_feature_state.sv`

Three forked threads:
1. **Tx thread**: Loops `pcie_dll_feature_seq` on the sequencer forever.
2. **Rx thread**: Pulls from `dllp_fifo`; on `DLLP_FEATURE_REQ` captures `feature_support`
   into `partner_cfg` and sets `feature_seq.seq_feature_ack=1`; on `DLLP_INITFC1_P` triggers
   `finished` event to exit early.
3. **Link-down thread**: Watches `lnk_cfg.pl_realesed`; triggers `finished` → `DL_INACTIVE`.

Exit: `finished` event OR both `feature_support_sent && partner_cfg.partner_feature_valid`.
Next state: `DL_INIT_FC1`.

#### `pcie_dll_DL_INIT_FC1`
**File**: `vip/agents/pcie_dll_initfc1_state.sv`

Three forked threads:
1. **Tx thread**: Runs `pcie_dll_init1_seq` once.
2. **Rx thread**: Pulls from `dllp_fifo` in a loop. Tracks in-order arrival of
   `INITFC1_P → INITFC1_NP → INITFC1_CPL` via `my_cfg.counter_fc1` (increments 0→1→2→3).
   Also accepts `INITFC2_*` in this state (stores credits via `partner_cfg.set_credits_value()`).
   Sets `my_cfg.fi1_set=1` when `counter_fc1==3` or all three rx flags set.
   Publishes `fc_pkt_counter_ap` after each received packet.
   Triggers `finished` → `DL_INIT_FC2`.
3. **Link-down thread**: Watches `lnk_cfg.pl_realesed` → `DL_INACTIVE`.

#### `pcie_dll_DL_INIT_FC2`
**File**: `vip/agents/pcie_dll_initfc2_state.sv`

Four forked threads:
1. **Tx thread**: Runs `pcie_dll_init2_seq`.
2. **Rx thread**: Tracks in-order `INITFC2_P → INITFC2_NP → INITFC2_CPL` via `my_cfg.counter_fc2`.
   Sets `my_cfg.fi2_set=1` when `counter_fc2==3`. Triggers `finished` → `DL_ACTIVE`.
3. **TLP shortcut**: If a TLP arrives in `tlp_fifo`, sets `fi2_set=1` and jumps to `DL_ACTIVE`
   immediately (spec-permitted shortcut).
4. **Link-down thread**: `lnk_cfg.pl_realesed` → `DL_INACTIVE`.

#### `pcie_dll_DL_ACTIVE`
**File**: `vip/agents/pcie_dll_active_state.sv`

Starts `pcie_dll_tlp_seq` on the sequencer. Stays active until `lnk_cfg.pl_realesed`
event → transitions to `DL_INACTIVE`.

---

## 9. Sequences

All sequences extend `pcie_dll_base_seq` (which extends `uvm_sequence #(pcie_dll_base_seq_item)`).

| Class | File | Purpose |
|---|---|---|
| `pcie_dll_feature_seq` | `sequences/pcie_dll_feature_seq.sv` | Sends `DLLP_FEATURE_REQ` packets. Randomises `req_count ∈ [1,5000]`, `feature_support=23'd1`, `feature_ack` set externally by Feature state. |
| `pcie_dll_init1_seq` | `sequences/pcie_dll_init1_seq.sv` | Sends `INITFC1_P`, `INITFC1_NP`, `INITFC1_CPL` in order. Credit values taken from `cfg.init_fc_hdr/data` arrays. Loops `cfg.req_count` times. |
| `pcie_dll_init2_seq` | `sequences/pcie_dll_init2_seq.sv` | Sends `INITFC2_P`, `INITFC2_NP`, `INITFC2_CPL` in order. Same credit values as FC1 round. |
| `pcie_dll_tlp_seq` | `sequences/pcie_dll_tlp_seq.sv` | Sends `pcie_dll_tlp_seq_item` once DL_ACTIVE. |
| `pcie_dll_if_seq` | `sequences/pcie_dll_if_seq.sv` | Interface-level sequence run on `pcie_dll_if_sqr`; used to toggle `pl_lnk_up` and trigger link events. |
| `send_single_packet` | `sequences/send_single_packet.sv` | Utility: sends one pre-built DLLP item. |

---

## 10. Transaction Models

### 10.1 `pcie_dll_base_seq_item`
**File**: `transactions/pcie_dll_base_seq_item.sv` | Extends `uvm_sequence_item`

Abstract base. Used as polymorphic handle throughout TLM ports. Concrete subclasses
are cast-identified at runtime with `$cast`.

### 10.2 `pcie_dll_dllp_seq_item`
**File**: `transactions/pcie_dll_dllp_seq_item.sv`

**Fields**:
- `rand pcie_dllp_type_e dllp_type` — constrained by `current_state`
- `rand pcie_dlcmsm_state_e current_state` — controls `dllp_type_constr`
- `bit [15:0] crc` — computed in `post_randomize` by `crc16_generator`
- `bit [23:0] dllp_payload` — assembled from sub-fields in `post_randomize`
- `bit [47:0] dllp` — final 6-byte wire word: `{crc, dllp_payload, dllp_type}`
- FC sub-fields: `rand bit[1:0] hdr_scale`, `rand bit[7:0] hdr_FC`, `rand bit[1:0] data_scale`, `rand bit[11:0] data_FC`
- Feature sub-fields: `rand bit[22:0] feature_support`, `rand bit feature_ack`
- `rand int unsigned delay` — cycles before driving (used when `cfg.delayed_packets`)
- Error-behaviour flags copied from `cfg` in `pre_randomize`: `enable_errors`, `corrupted_initfc`, `delayed_packets`

**Constraints**:
- `dllp_type_constr`: restricts type to state-legal values (Feature→`FEATURE_REQ`, FC1→`INITFC1_*`, FC2→`INITFC2_*`)
- `initfc1_credit`: credit values equal cfg arrays for the matching FC type
- `delay_constr`: `dist {0:=20, 10000:=30, 35000:=50}`

**Key methods**:
- `post_randomize()`: assembles `dllp_payload`, computes CRC, builds `dllp` wire word
- `pack()` / `unpack(bit[47:0])`: serialise / deserialise DLLP bytes
- `pack_data()`: returns 4 pre-CRC bytes in wire order for CRC input
- `verify_crc()`: compares stored CRC against recomputed value

### 10.3 `pcie_dll_tlp_seq_item`
**File**: `transactions/pcie_dll_tlp_seq_item.sv`

- `bit [127:0] tlp` — raw 16-byte TLP payload (drives bytes 0–15 on the bus)

### 10.4 `pcie_dll_if_seq_item`
**File**: `transactions/pcie_dll_if_seq_item.sv`

Used by `pcie_dll_if_drv` to carry link-level commands (e.g., assert/deassert `pl_lnk_up`).

---

## 11. Scoreboard — `pcie_dll_scoreboard`

**File**: `vip/scoreboards/pcie_dll_scoreboard.sv` | Extends `uvm_scoreboard`

One instance per `pcie_dll_env`. Instantiates a `pcie_dll_common_checks` object.

### 11.1 Analysis Ports (Inputs)

| Port (suffix macro) | Item type | Source |
|---|---|---|
| `tx_export` (`_tx`) | `pcie_dll_base_seq_item` | `agent.agent_tx_ap` (Tx monitor) |
| `rx_export` (`_rx`) | `pcie_dll_base_seq_item` | `agent.agent_rx_ap` (Rx monitor) |
| `state_export` (`_state`) | `pcie_dlcmsm_state_e` | `agent.state_ap` (state manager) |
| `counter_export` (`_counter`) | `pcie_fc_pkt_counters_s` | `agent.agent_counter_ap` |

### 11.2 Internal Queues

Items arrive asynchronously via `write_*` functions and are pushed onto `tx_queue`, `rx_queue`,
and `counters_queue`. The `run_phase` loop waits for all three queues to be non-empty before
popping and running checks (the counter queue is bypassed in `DL_FEATURE_EXCH` and `DL_ACTIVE`).

### 11.3 `write_tx` — Tx-Path Checks

- Sets `feat_dllp_sent = 1` the first time a `DLLP_FEATURE_REQ` is observed on Tx.
- **FATAL** (`uvm_fatal`) if a non-DLLP item (TLP) is observed while `my_cfg.dlsm_state != DL_ACTIVE`.

### 11.4 `write_rx` — Rx-Path Checks

**Feature DLLP checks** (called immediately on Rx, not queued):
- `check_feature_reserved_zero`: bits `[22:1]` of `feature_support` must be zero (ERROR).
- **Feature Ack Handshake**: `feature_ack==1` while `feat_dllp_sent==0` → ERROR
  (partner is asserting ack before we ever sent a Feature DLLP).

**InitFC ordering** (called immediately on Rx):
- `check_fc_strict_order` for InitFC1 round: enforces `P → NP → Cpl` sequence via
  `rx_initfc1_order_step` (0→1→2→3). Out-of-order → ERROR.
- Same check for InitFC2 round via `rx_initfc2_order_step`.

**Traffic isolation**:
- TLP received while state is not in `{DL_INIT_FC2, DL_ACTIVE, DL_INACTIVE}` → FATAL.

### 11.5 `write_state` — State Transition Checks

Checks run synchronously on every state broadcast from the state manager:

| Check | Severity | Condition |
|---|---|---|
| `check_init_trigger` | FATAL | `DL_INACTIVE → DL_FEATURE_EXCH/DL_INIT_FC1` while `pl_lnk_up==0` |
| `check_state_stability` | FATAL | Any forward state regresses to `DL_INACTIVE` while `pl_lnk_up==1` |
| `check_active_gate_fi1` | FATAL | `DL_INIT_FC1 → DL_INIT_FC2` before `my_cfg.fi1_set` |
| `check_active_gate_fi2` | FATAL | `DL_INIT_FC2 → DL_ACTIVE` before `my_cfg.fi2_set` |
| `check_valid_transition` | FATAL | Transition not in the allowed set |

Allowed DLCMSM transitions:
```
DL_INACTIVE     → DL_FEATURE_EXCH  or  DL_INIT_FC1
DL_FEATURE_EXCH → DL_INIT_FC1      or  DL_INACTIVE
DL_INIT_FC1     → DL_INIT_FC2      or  DL_INACTIVE
DL_INIT_FC2     → DL_ACTIVE        or  DL_INACTIVE
DL_ACTIVE       → DL_INACTIVE
```

State counters (`rx_initfc1_order_step`, `rx_initfc2_order_step`, `feat_dllp_sent`) are
reset to 0 whenever the state returns to `DL_INACTIVE`.

### 11.6 `run_phase` — Queued Checks

Run on each `{tx_item, rx_item, counters}` triple popped from queues:

| Check | Severity | Function |
|---|---|---|
| `proper_packets` | ERROR | Invalid DLLP type for current state (via `error_expector`) |
| `proper_packets` | ERROR | TLP received while link not active |
| `valid_VC` | ERROR | InitFC DLLP with non-zero VC field |
| `check_symmetric_active` | FATAL | RC/EP state delta > 1 when either is in DL_ACTIVE |
| `Credit_Capture` | ERROR | Received FC credit values don't match previously stored partner values |
| `drop_packets` | ERROR | State manager counter did not increment (or increment when it should have dropped) |

### 11.7 `pcie_dll_common_checks`

**File**: `vip/scoreboards/common_checks.sv` | Extends `uvm_object`

Pure-function helper class (no ports). All functions return 0 (fail) or 1/2 (pass/skip):

- `check_init_trigger`, `check_valid_transition`, `check_state_stability`
- `check_active_gate_fi1`, `check_active_gate_fi2`
- `check_fc_strict_order` — generic order checker for any P/NP/Cpl triplet
- `check_feature_reserved_zero` — bits `[22:1]` of `feature_support` must be zero
- `proper_packets` — delegates to `error_expector::rx_determine_error_status`
- `valid_VC` — delegates to `error_expector::rx_determine_error_status`
- `drop_packets` — validates counter increment/drop behaviour against `WRONG_CRC` flag
- `check_symmetric_active` — validates state-delta between Tx FSM state and Rx DLLP type
- `Credit_Capture` — compares received FC fields against `partner_cfg.partner_credits`

---

## 12. FC Watchdog — `pcie_dll_fc_watchdog`

**File**: `vip/scoreboards/pcie_dll_fc_watchdog.sv` | Extends `uvm_component`

One instance per `pcie_dll_env`. Enforces the 34 µs DLLP arrival interval mandated by
PCIe Base Spec Rev 5.0 during `DL_FEATURE_EXCH`, `DL_INIT_FC1`, and `DL_INIT_FC2`.

### 12.1 Analysis Ports (Inputs)

| Port (suffix macro) | Item type | Source |
|---|---|---|
| `rx_export` (`_wd_rx`) | `pcie_dll_base_seq_item` | `agent.agent_rx_ap` |
| `state_export` (`_wd_state`) | `pcie_dlcmsm_state_e` | `agent.state_ap` |

(Uses `_wd_rx` / `_wd_state` suffix macros to avoid clashing with scoreboard's `_rx` / `_state`.)

### 12.2 Watchdog Threads (forked in `run_phase`)

Three parallel threads, one per initialization phase:

| Thread | State watched | Reset trigger DLLP | Interval |
|---|---|---|---|
| `run_feature_watchdog` | `DL_FEATURE_EXCH` | `DLLP_FEATURE_REQ` | `cfg.init_rx_interval_cycles` |
| `run_fc1_watchdog` | `DL_INIT_FC1` | `DLLP_INITFC1_P` | `cfg.init_rx_interval_cycles` |
| `run_fc2_watchdog` | `DL_INIT_FC2` | `DLLP_INITFC2_P` | `cfg.init_rx_interval_cycles` |

Each thread uses a three-way `fork/join_any` inside a `while(in_state)` loop:
- **Timer thread**: counts `repeat(cfg.init_rx_interval_cycles) @(posedge vif.lclk)` — fires `uvm_error` on timeout.
- **Reset thread**: waits on local SV event (`fc1_set_started`, `fc2_set_started`, `feature_dllp_received`) to restart the count.
- **Exit thread**: `wait(curr_state != target_state)` — breaks the loop cleanly.

On timeout, the thread also triggers the matching `uvm_event` (`timeout_event_fc1/fc2/feature`)
from the global `uvm_event_pool` so that coverage can sample the timeout scenario.

---

## 13. Coverage — `pcie_dll_coverage`

**File**: `vip/coverage/pcie_dll_coverage.sv` | Extends `uvm_subscriber #(pcie_dll_base_seq_item)`

Two instances per `pcie_dll_env` (`cov_tx` sampled from Tx ap, `cov_rx` from Rx ap).
Role and path type (`"Tx_path"` / `"Rx_path"`) determined by instance name matching `"*tx*"`.

### 13.1 Covergroups

| Covergroup | Instances | Key Coverpoints |
|---|---|---|
| `tx_machine_transitions` | Tx path only | State-machine arc transitions: `DL_INACTIVE→DL_FEATURE_EXCH`, `→DL_INIT_FC1`, `DL_INIT_FC1→DL_INIT_FC2`, `DL_INIT_FC2→DL_ACTIVE` |
| `cg_dllp_transitions` | Both paths | `cp_state` (Feature/FC1/FC2), `cp_dllp_type`, `cp_error_status`; crosses: `cr_inv_dllp`, `cr_wrong_crc`, `cr_invalid_vc`; InitFC sequencing bins (B2B, disorder, repeated, cross-round); zero-credit bins |
| `cg_watchdog` | Rx path only | `cp_watchdog_status`: `timeout_feature`, `timeout_fc1`, `timeout_fc2` |
| `cg_tlp_transitions` | Both paths | `cp_tlp`: single expected TLP magic value |

### 13.2 Sampling

`write(item)` is called by UVM subscriber infrastructure on each published item:
- Reads `my_cfg.dlsm_state` for the current state context.
- Calls `error_expector::tx/rx_determine_error_status` to classify the item.
- Samples the appropriate covergroup.

`cg_watchdog` is sampled asynchronously in `run_phase` via `uvm_event_pool` listeners for
`timeout_event_fc1/fc2/feature` — triggered by the FC watchdog on each timeout.

---

## 14. Helper Classes

### 14.1 `crc16_generator`
**File**: `vip/helpers/crc16_generator.sv` | Static class

- `static function bit[15:0] calculate_dllp_crc(bit[31:0] data)` — computes the 16-bit
  DLLP CRC over the 4 pre-CRC bytes in wire order. Used by `pcie_dll_dllp_seq_item` and
  `error_expector`.

### 14.2 `error_expector`
**File**: `vip/helpers/error_expector.sv` | Static class

Two static functions used by scoreboard, coverage, and common_checks:

**`tx_determine_error_status(item, state)`** — classifies an outgoing item:
- `WRONG_CRC`: `verify_crc()` returns 0
- `INVALID_DLLP`: type not legal for `state` (e.g., non-Feature DLLP in `DL_FEATURE_EXCH`)
- `INVALID_VC`: InitFC DLLP with non-zero VC bits (`dllp[2:0] != 3'b000`) in FC states
- `INVALID_TLP`: TLP emitted before `DL_ACTIVE`
- `ERROR_FREE`: all checks pass

**`rx_determine_error_status(item, state)`** — classifies an incoming item (slightly more
permissive during overlap states, e.g., `DL_INIT_FC1` accepts lingering Feature DLLPs).

### 14.3 `pcie_dll_report_catcher`
**File**: `vip/helpers/pcie_dll_report_catcher.sv` | Extends `uvm_report_catcher`

A UVM report catcher that selectively demotes **expected** `UVM_ERROR` messages to
`UVM_INFO` in error-injection tests, so that tests which intentionally trigger protocol
violations still exit with a clean simulation status.

**Matching strategy** — single `expected_msg_tags[$]` queue, checked via `uvm_is_match`
against the **full message string** for every `UVM_ERROR` regardless of its ID:
- Scoreboard errors all share ID `"SCOREBOARD"` — tags like `"ILLEGAL_DLLP"`,
  `"PKT_DROP"`, `"INITFC1_OUT_OF_ORDER"` appear as a recognisable prefix in the message.
- Watchdog errors all share ID `"WDOG"` — state-specific tags `"FEAT_TIMEOUT"`,
  `"FC1_TIMEOUT"`, `"FC2_TIMEOUT"` are embedded in the message string.
- A single tag queue and a single substring match covers both component families.

**UVM_FATAL messages are never touched** — only `UVM_ERROR` is intercepted.

**Lifecycle**:
1. `pcie_dll_test_base.start_of_simulation_phase` creates one catcher and calls
   `uvm_report_cb::add(null, catcher)` to register it globally (all components).
2. Each error-injection derived test overrides `start_of_simulation_phase`, calls
   `super` (which creates and registers the catcher), then calls
   `catcher.add_expected_tag(...)` for every error ID it deliberately triggers.
3. `pcie_dll_test_base.final_phase` calls `catcher.report()` to print the summary.

**Per-test expected tags**:

| Test | Tags registered |
|---|---|
| `test_base_error_injected` | `ILLEGAL_DLLP`, `INITFC1_OUT_OF_ORDER`, `INITFC2_OUT_OF_ORDER`, `VIRTUAL_CHANNEL`, `PKT_DROP` |
| `test_base_corrupted_initfc` | `INITFC1_OUT_OF_ORDER`, `INITFC2_OUT_OF_ORDER`, `PKT_DROP` |
| `test_base_delayed_packets` | `FEAT_TIMEOUT`, `FC1_TIMEOUT`, `FC2_TIMEOUT` |
| All other tests | *(none — any UVM_ERROR is a genuine failure)* |

**Summary output** (printed at `UVM_NONE` in `final_phase`):
```
--------------------------------------------------
   EXPECTED ERROR DEMOTION SUMMARY
--------------------------------------------------
  INITFC1_OUT_OF_ORDER      : 7
  INITFC2_OUT_OF_ORDER      : 4
  PKT_DROP                  : 3
--------------------------------------------------
  Total demoted errors: 14
--------------------------------------------------
  UNEXPECTED ERRORS: 0          ← section only appears if count > 0
--------------------------------------------------
```
Unexpected errors (UVM_ERRORs that were thrown but not matched by any registered tag)
are collected in `unexpected_errors[$]` and printed individually in the summary,
giving a clear post-simulation triage view.

---

## 15. File Map (Implemented)

```
pcie-gen5-dll-vip/
├── tb/
│   ├── tb_top.sv                        # Top module — clock, reset, interfaces, run_test()
│   └── pcie_lpif_if.sv                  # LPIF interface + 8 SVA properties + 3 clocking blocks
│
├── rtl/
│   └── mock_phy_crossbar.sv             # B2B loopback; zero-latency; compile-time tie-offs
│
└── vip/
    ├── pcie_dll_pkg.sv                  # Package — enums, structs, `include order
    │
    ├── env/
    │   ├── pcie_dll_env_cfg.sv          # Shared per-side config (hw params + knobs)
    │   ├── pcie_dll_partner_cfg.sv      # Runtime partner credit/feature storage
    │   ├── pcie_dll_my_cfg.sv           # Local FSM tracking (state, counters, fi1/fi2)
    │   ├── pcie_dll_link_cfg.sv         # Shared link-up/reset events
    │   └── pcie_dll_env.sv              # Unified environment (role-parameterised)
    │
    ├── agents/
    │   ├── pcie_dll_agent.sv            # Active agent — owns all sub-components
    │   ├── pcie_dll_seqr.sv             # Sequencer (uvm_sequencer #(pcie_dll_base_seq_item))
    │   ├── pcie_dll_tx_drv.sv           # Tx driver — LPIF signal-level driving
    │   ├── pcie_dll_tx_drv_cb_base.sv   # Callback base class
    │   ├── pcie_dll_tx_drv_cb_macro.svh # `pcie_do_callbacks_one_hot macro
    │   ├── pcie_dll_tx_drv_cb_crc.sv    # CRC corruption callback
    │   ├── pcie_dll_tx_drv_cb_invalid_dllp.sv  # Invalid DLLP type callback
    │   ├── pcie_dll_tx_drv_cb_vc.sv     # Invalid VC callback
    │   ├── pcie_dll_tx_mon.sv           # Tx snoop monitor
    │   ├── pcie_dll_rx_mon.sv           # Rx monitor
    │   ├── pcie_dll_state_mgr.sv        # DLCMSM state manager (FSM orchestrator)
    │   ├── pcie_dll_base_state.sv       # Abstract state base class
    │   ├── pcie_dll_inactive_state.sv   # DL_INACTIVE state
    │   ├── pcie_dll_feature_state.sv    # DL_FEATURE_EXCH state
    │   ├── pcie_dll_initfc1_state.sv    # DL_INIT_FC1 state
    │   ├── pcie_dll_initfc2_state.sv    # DL_INIT_FC2 state
    │   ├── pcie_dll_active_state.sv     # DL_ACTIVE state
    │   └── interface_agent/
    │       ├── pcie_dll_if_agent.sv     # Interface-level agent (link control)
    │       ├── pcie_dll_if_drv.sv       # Drives pl_lnk_up; fires link events
    │       ├── pcie_dll_if_mon.sv       # Monitors lnk_vif; updates link_cfg events
    │       └── pcie_dll_if_sqr.sv       # Sequencer for if_seq
    │
    ├── transactions/
    │   ├── pcie_dll_base_seq_item.sv    # Abstract base item
    │   ├── pcie_dll_dllp_seq_item.sv    # 6-byte DLLP item (CRC, FC credits, Feature fields)
    │   ├── pcie_dll_tlp_seq_item.sv     # 16-byte raw TLP item
    │   └── pcie_dll_if_seq_item.sv      # Link-control command item
    │
    ├── sequences/
    │   ├── pcie_dll_base_seq.sv         # Base sequence
    │   ├── pcie_dll_feature_seq.sv      # Feature DLLP traffic
    │   ├── pcie_dll_init1_seq.sv        # InitFC1 P/NP/Cpl in order
    │   ├── pcie_dll_init2_seq.sv        # InitFC2 P/NP/Cpl in order
    │   ├── pcie_dll_tlp_seq.sv          # TLP traffic (DL_ACTIVE)
    │   ├── pcie_dll_if_seq.sv           # Link-level event sequence
    │   └── send_single_packet.sv        # Single-shot DLLP utility
    │
    ├── scoreboards/
    │   ├── pcie_dll_scoreboard.sv       # Main scoreboard (state + FC + credit checks)
    │   ├── common_checks.sv             # Pure-function check library
    │   └── pcie_dll_fc_watchdog.sv      # 34 µs interval watchdog (Feature + FC1 + FC2)
    │
    ├── coverage/
    │   └── pcie_dll_coverage.sv         # Functional + cross + watchdog covergroups
    │
    ├── helpers/
    │   ├── crc16_generator.sv           # Static CRC-16 computation
    │   ├── error_expector.sv            # Static Tx/Rx error classification
    │   └── pcie_dll_report_catcher.sv   # UVM report catcher for expected-error demotion
    │
    └── tests/
        ├── test_base.sv                 # Base test (config, roles, env instantiation, report catcher)
        ├── test_base_with_feature.sv    # Normal bring-up with DL_FEATURE_EXCH
        ├── test_base_without_feature.sv # Bring-up skipping feature exchange
        ├── test_base_corrupted_initfc.sv# Disordered/repeated InitFC packets
        ├── test_base_error_injected.sv  # CRC + invalid-DLLP error injection
        ├── test_base_delayed_packets.sv # Randomised inter-packet delays
        ├── test_base_zero_credits.sv    # Zero initial FC credit advertisement
        └── test_base_drop_link.sv       # Random-state link-drop resilience (10 reps)
```

---

## 16. Key Design Decisions

1. **Unified Role-Based Classes**: Every component class (`pcie_dll_env`, `pcie_dll_agent`,
   `pcie_dll_tx_drv`, etc.) is instantiated twice with a `pcie_dll_role_e` field (`ROLE_RC` /
   `ROLE_EP`). No separate RC/EP subclasses exist — role drives conditional logic inline.

2. **Strategy Pattern for DLCMSM**: The FSM is implemented using the State design pattern.
   `pcie_dll_state_mgr` holds a `pcie_dll_base_state` handle; concrete state objects are
   created by `uvm_factory` at runtime using the enum name as the class name string.
   This makes adding new states trivial without modifying the manager.

3. **Five-State DLCMSM**: The implemented FSM has five states —
   `DL_INACTIVE → DL_FEATURE_EXCH → DL_INIT_FC1 → DL_INIT_FC2 → DL_ACTIVE`.
   `DL_FEATURE_EXCH` is optional; the scoreboard and `check_valid_transition` permit
   `DL_INACTIVE → DL_INIT_FC1` directly (used by `test_base_without_feature`).

4. **Separated Config Objects**: Three config objects share responsibility:
   - `pcie_dll_env_cfg` — static knobs set by the test, never mutated at runtime.
   - `pcie_dll_my_cfg` — mutable local FSM state (`dlsm_state`, counters, fi1/fi2 gates).
   - `pcie_dll_partner_cfg` — mutable partner state (credits, feature support).
   This separation prevents the test config from being polluted by runtime state.

5. **FI1 / FI2 Gate Flags**: `my_cfg.fi1_set` and `my_cfg.fi2_set` are boolean gates
   set by the FSM states and checked by the scoreboard on every state transition.
   They are the single source of truth for "all InitFC1 / InitFC2 received" conditions.

6. **Callback-Based Error Injection**: Three concrete Tx driver callbacks (`cb_crc`,
   `cb_invalid_dllp`, `cb_vc`) are added per-test via `uvm_callbacks::add`. Each callback
   reads `item.enable_errors` / `item.corrupted_initfc` before mutating the item, so the
   same callbacks are inert in clean tests.

7. **FC Watchdog as Separate Component**: `pcie_dll_fc_watchdog` is a standalone
   `uvm_component` (not part of the scoreboard) that directly accesses the LPIF virtual
   interface for clock edges. Its timeout events are published to the global
   `uvm_event_pool` so the coverage class can sample them without a direct port connection.

8. **Dual Coverage Instances**: Each env instantiates `cov_tx` and `cov_rx` as separate
   `pcie_dll_coverage` instances. The instance name determines whether the Tx-only
   `tx_machine_transitions` covergroup and the Rx-only `cg_watchdog` covergroup are created.

9. **CRC Not Filtered at Monitor**: The Rx monitor publishes all reconstructed DLLPs
   regardless of CRC validity. CRC classification is centralised in `error_expector` and
   consumed by both scoreboard and coverage, avoiding duplicated logic.

10. **Compile-Time ↔ Runtime Bridge**: LPIF hardware parameters (`NBYTES=64`, link width,
    speed) are `localparam` in `tb_top` (required for parameterised interface widths), then
    published to `uvm_config_db`. `pcie_dll_env_cfg.set_defaults()` initialises them; the
    test's `build_phase` overrides them from the DB, ensuring single-source-of-truth for
    both RTL and UVM layers.

11. **Link-Resilience Test Pattern** (`test_base_drop_link`): Rather than hard-coding a
    single drop point, the test randomises `link_drop_target_state` over the full
    `pcie_dlcmsm_state_e` enum on every iteration. Both RC and EP are `wait`-ed to reach
    the same target state before `pcie_dll_if_seq` pulls `pl_lnk_up` low. Each concrete
    state class (Feature, InitFC1, InitFC2, Active) contains **Thread 3** — a dedicated
    `fork` branch that waits on `lnk_cfg.pl_realesed` and immediately triggers the `finished`
    event to unblock the FSM and return to `DL_INACTIVE`. No scoreboard errors are expected;
    a clean pass confirms full state-machine resilience against link teardown at any phase.

12. **Interface-Level SVA Block**: Eight `assert property` constructs live directly inside
    `pcie_lpif_if.sv` (not in a separate bind file). This gives them unconditional visibility
    in simulation without any bind-target lookup and zero simulator-specific elaboration flags.
    All framing/handshake properties use `disable iff (!rst_n || !pl_lnk_up)` so they are
    silent during reset and link-down — the only exception is `CHK_LNK_DOWN_FLUSH` and
    `CHK_NO_X_STATES`, which remain active during link-down to catch flush and X-state
    violations precisely in those conditions.
