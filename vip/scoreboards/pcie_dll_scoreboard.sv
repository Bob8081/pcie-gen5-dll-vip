// Declare specific imp suffixes for scoreboard analysis ports
`uvm_analysis_imp_decl(_tx)
`uvm_analysis_imp_decl(_rx)
`uvm_analysis_imp_decl(_state)
`uvm_analysis_imp_decl(_counter)

class pcie_dll_scoreboard extends uvm_scoreboard;

  pcie_dll_role_e role;

  // Track states for note: "we don't need this because item alreadt has the updated state " 
  pcie_dlcmsm_state_e prev_state;
  pcie_dlcmsm_state_e curr_state;
  bit state_seeded;

  // Track transmitted DLLP
  pcie_dll_dllp_seq_item  tx_dllp_item;
  pcie_dlcmsm_state_e     tx_prev_state;
  pcie_dlcmsm_state_e     tx_curr_state;
  pcie_dllp_type_e        tx_prev_dllp_type;
  pcie_dllp_type_e        tx_curr_dllp_type;

  // Track received DLLP
  pcie_dll_dllp_seq_item  rx_dllp_item;
  pcie_dlcmsm_state_e     rx_prev_state;
  pcie_dlcmsm_state_e     rx_curr_state;
  pcie_dllp_type_e        rx_prev_dllp_type;
  pcie_dllp_type_e        rx_curr_dllp_type;

  // Track state manager counters
  pcie_state_mgr_counters_s prev_counters;
  pcie_state_mgr_counters_s curr_counters;


  // Track RX DLLP ordering
  int unsigned rx_initfc1_order_step; // P->0, NP->1, Cpl->2
  int unsigned rx_initfc2_order_step; // P->0, NP->1, Cpl->2

  // Analysis implementation ports
  uvm_analysis_imp_tx        #(pcie_dll_base_seq_item, pcie_dll_scoreboard) tx_export;
  uvm_analysis_imp_rx        #(pcie_dll_base_seq_item, pcie_dll_scoreboard) rx_export;
  uvm_analysis_imp_state     #(pcie_dlcmsm_state_e,    pcie_dll_scoreboard) state_export;
  uvm_analysis_imp_counter #(pcie_state_mgr_counters_s, pcie_dll_scoreboard) counter_export; // counter item


  // Handle to common checks
  pcie_dll_common_checks checks;

  // Configuration handles
  pcie_dll_env_cfg cfg;
  pcie_dll_link_cfg lnk_cfg;
  pcie_dll_partner_cfg partner_cfg;
  pcie_dll_my_cfg my_cfg;

  `uvm_component_utils(pcie_dll_scoreboard)

  function new(string name = "pcie_dll_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    curr_state = DL_INACTIVE;
    prev_state = DL_INACTIVE;
    tx_prev_state = DL_INACTIVE;
    tx_curr_state = DL_INACTIVE;
    rx_prev_state = DL_INACTIVE;
    rx_curr_state = DL_INACTIVE;
    state_seeded  = 0;
    rx_initfc1_order_step = 0;
    rx_initfc2_order_step = 0;
    tx_export      = new("tx_export",    this);
    rx_export      = new("rx_export",    this);
    state_export   = new("state_export", this);
    counter_export = new("counter_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    checks = pcie_dll_common_checks::type_id::create("checks");
    if(!uvm_config_db#(pcie_dll_link_cfg)::get(this, "", "lnk_cfg", lnk_cfg)) begin
      `uvm_fatal("NOCFG", $sformatf("no link cfg found in the config_db for %s scoreboard", role.name()))
    end
    if(!uvm_config_db#(pcie_dll_my_cfg)::get(this, "", "my_cfg", my_cfg)) begin
      `uvm_fatal("NOCFG", $sformatf("no my_cfg found in the config_db for %s scoreboard", role.name()))
    end
    if(!uvm_config_db#(pcie_dll_partner_cfg)::get(this, "", "partner_cfg", partner_cfg)) begin
      `uvm_fatal("NOCFG", $sformatf("no partner_cfg found in the config_db for %s scoreboard", role.name()))
    end
    if(!uvm_config_db#(pcie_dll_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("NOCFG", $sformatf("no env_cfg found in the config_db for %s scoreboard", role.name()))
    end
  endfunction

  // Called when the Tx monitor publishes a driven DLLP
  virtual function void write_tx(pcie_dll_base_seq_item item);
    // TODO: cross-validate Tx-driven DLLPs against expected protocol state
    pcie_dll_dllp_seq_item dllp_item;

    if (!$cast(dllp_item, item) && (dllp_item.current_state != DL_ACTIVE)) begin
      `uvm_fatal("TRAFFIC_ISOLATION", "Violation: TLP detected while Link is NOT ACTIVE!")
    end

    tx_dllp_item      = dllp_item;
    tx_prev_state     = tx_curr_state;
    tx_curr_state     = dllp_item.current_state;
    tx_prev_dllp_type = tx_curr_dllp_type;
    tx_curr_dllp_type = dllp_item.dllp_type;

    checks.tx_updated = 1'b1; // Set the flag to indicate a new Tx item has been processed
    // calling some common checks
    checks.check_symmetric_active (tx_prev_state, tx_curr_state, 
                                   rx_prev_state, rx_curr_state);
    //TODO : add the same checks as the write_rx ones .. no?
  endfunction

  // Called when the Rx monitor publishes a received DLLP
  virtual function void write_rx(pcie_dll_base_seq_item item);
    pcie_dll_dllp_seq_item dllp_item;
    int unsigned next_order_step;
    string fatal_msg;

    if ((!$cast(dllp_item, item)) && (dllp_item.current_state != DL_ACTIVE) ) begin
      `uvm_fatal("TRAFFIC_ISOLATION", "Violation: TLP detected while Link is NOT ACTIVE!")
    end

    rx_dllp_item      = dllp_item;
    rx_prev_state     = rx_curr_state;
    rx_curr_state     = dllp_item.current_state;
    rx_prev_dllp_type = rx_curr_dllp_type;
    rx_curr_dllp_type = dllp_item.dllp_type;

    // Check: Reserved Fields Zero 
    // Bits [22:1] of the Feature Supported field must be zero.
    if (dllp_item.dllp_type == DLLP_FEATURE_REQ) begin
      if (!checks.check_feature_reserved_zero(dllp_item.feature_support)) begin
        fatal_msg = $sformatf(
          "SPEC VIOLATION: Received DLLP_FEATURE_REQ with non-zero reserved bits. feature_support = 23'h%06h — bits [22:1] must be zero (only bit 0 = Scaled FC is valid).",
          dllp_item.feature_support);
        `uvm_error("SCOREBOARD", fatal_msg)
      end else begin
        `uvm_info("SCOREBOARD",
          $sformatf("PASS: DLLP_FEATURE_REQ reserved bits [22:1] are zero. feature_support = 23'h%06h.",
            dllp_item.feature_support), UVM_LOW)
      end
    end

    // Check InitFC1 Order
    if (rx_initfc1_order_step < 3 &&
        (dllp_item.dllp_type == DLLP_INITFC1_P ||
          dllp_item.dllp_type == DLLP_INITFC1_NP ||
          dllp_item.dllp_type == DLLP_INITFC1_CPL)) begin

      if (!checks.check_fc_strict_order(dllp_item.dllp_type,
            rx_initfc1_order_step,
            DLLP_INITFC1_P,
            DLLP_INITFC1_NP,
            DLLP_INITFC1_CPL,
            next_order_step)) begin
        fatal_msg = $sformatf("ERROR: InitFC1 DLLPs out of order. Expected step %0d, observed %s.",
          rx_initfc1_order_step, dllp_item.dllp_type.name());
        `uvm_error("SCOREBOARD", fatal_msg)
      end else begin
        rx_initfc1_order_step = next_order_step;
      end
    end

    // Check InitFC2 Order
    if (rx_initfc2_order_step < 3 &&
        (dllp_item.dllp_type == DLLP_INITFC2_P ||
          dllp_item.dllp_type == DLLP_INITFC2_NP ||
          dllp_item.dllp_type == DLLP_INITFC2_CPL)) begin

      if (!checks.check_fc_strict_order(dllp_item.dllp_type,
            rx_initfc2_order_step,
            DLLP_INITFC2_P,
            DLLP_INITFC2_NP,
            DLLP_INITFC2_CPL,
            next_order_step)) begin
        fatal_msg = $sformatf("ERROR: InitFC2 DLLPs out of order. Expected step %0d, observed %s.",
          rx_initfc2_order_step, dllp_item.dllp_type.name());
        `uvm_error("SCOREBOARD", fatal_msg)
      end else begin
        rx_initfc2_order_step = next_order_step;
      end
    end

    checks.rx_updated = 1'b1; // Set the flag to indicate a new Rx item has been processed
    // calling some common checks
    checks.traffic_isolation_check (dllp_item);

    checks.check_symmetric_active  (tx_prev_state, tx_curr_state, 
                                    rx_prev_state, rx_curr_state);

    checks.drop_packets            (rx_curr_dllp_type, rx_prev_dllp_type,
                                    curr_counters    , prev_counters,
                                    rx_curr_state    , rx_prev_state ,
                                    rx_dllp_item );

    checks.Credit_Capture          (dllp_item, partner_cfg);

endfunction


  // Called when the state manager publishes a new state
  virtual function void write_counter (pcie_state_mgr_counters_s counters);
        prev_counters.counter_fc1  = curr_counters.counter_fc1;
        prev_counters.counter_fc2  = curr_counters.counter_fc2;
        curr_counters.counter_fc2  = counters.counter_fc2;
        curr_counters.counter_fc1  = counters.counter_fc1;

        checks.counter_update = 1'b1; // Set the flag to indicate a new counter item has been processed
        // calling some common checks
        checks.drop_packets (rx_curr_dllp_type, rx_prev_dllp_type,
                             curr_counters    , prev_counters,
                             rx_curr_state    , rx_prev_state,
                             rx_dllp_item );


  endfunction

  // This function is called automatically when the state_mgr writes to the port
  virtual function void write_state(pcie_dlcmsm_state_e new_state);
    string fatal_msg;

    if (!state_seeded) begin
      prev_state = new_state;
      curr_state = new_state;
      state_seeded = 1;
      if (new_state == DL_INACTIVE) begin
        rx_initfc1_order_step = 0;
        rx_initfc2_order_step = 0;
      end
      return;
    end

    // 1. Shift the history
    prev_state = curr_state;
    curr_state = new_state;

    if (curr_state == DL_INACTIVE) begin
      rx_initfc1_order_step = 0;
      rx_initfc2_order_step = 0;
    end

    // 2. Perform state transition checks
    if (!checks.check_init_trigger(prev_state, curr_state, lnk_cfg.pl_up)) begin
      fatal_msg = $sformatf("FATAL: State transition DL_INACTIVE -> %s occurred while pl_lnk_up=%0b. Link must be UP before entering DL_Init state.",
        curr_state.name(), lnk_cfg.pl_up);
      `uvm_fatal("SCOREBOARD",
        fatal_msg)
    end else if (!checks.check_state_stability(prev_state, curr_state, lnk_cfg.pl_up)) begin
      fatal_msg = $sformatf("FATAL: State regression %s -> %s is not allowed while pl_lnk_up=%0b. Once in DL_Active, state must remain stable.",
        prev_state.name(), curr_state.name(), lnk_cfg.pl_up);
      `uvm_fatal("SCOREBOARD",
        fatal_msg)
    end else if (!checks.check_active_gate_fi1(prev_state, curr_state, my_cfg.fi1_set)) begin
      fatal_msg = "FATAL: DL_INIT_FC1 -> DL_INIT_FC2 occurred before FI1 was set. FI1 must be asserted only after all InitFC1 credits are recorded for P, NP, and Cpl.";
      `uvm_fatal("SCOREBOARD",
        fatal_msg)

    end else if (!checks.check_active_gate_fi2(prev_state, curr_state, my_cfg.fi2_set)) begin
      fatal_msg = "FATAL: DL_Init -> DL_Active occurred before FI2 was set. FI2 must be asserted by an InitFC2 DLLP or TLP on VC0 first.";
      `uvm_fatal("SCOREBOARD",
        fatal_msg)
    end else if (!checks.check_valid_transition(prev_state, curr_state)) begin
      fatal_msg = $sformatf("FATAL: Illegal DLCMSM transition %s -> %s. Allowed paths are: DL_Inactive -> DL_Feature -> DL_Init -> DL_Active or DL_Inactive -> DL_Init -> DL_Active.",
        prev_state.name(), curr_state.name());
      `uvm_fatal("SCOREBOARD",
        fatal_msg)
    end else begin
      `uvm_info("SCOREBOARD",
        $sformatf("PASS: Valid state transition %s -> %s with pl_lnk_up=%0b.",
          prev_state.name(), curr_state.name(), lnk_cfg.pl_up), UVM_LOW)
    end
  endfunction

endclass : pcie_dll_scoreboard