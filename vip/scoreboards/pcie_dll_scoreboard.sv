// Declare specific imp suffixes for scoreboard analysis ports
`uvm_analysis_imp_decl(_tx)
`uvm_analysis_imp_decl(_rx)
`uvm_analysis_imp_decl(_state)
`uvm_analysis_imp_decl(_counter)

class pcie_dll_scoreboard extends uvm_scoreboard;

  pcie_dll_role_e role;

  // Track states
  pcie_dlcmsm_state_e prev_state;
  pcie_dlcmsm_state_e curr_state;
  bit state_seeded;

  // Track transmitted packet
  pcie_dll_base_seq_item  tx_item;
  pcie_dll_dllp_seq_item  tx_dllp_item;

  // Track received packet
  pcie_dll_base_seq_item  rx_item;
  pcie_dll_dllp_seq_item  rx_dllp_item;

  // Track state manager counters
  pcie_fc_pkt_counters_s prev_counters;
  pcie_fc_pkt_counters_s curr_counters;
  pcie_fc_pkt_counters_s temp_counters;

  // Queues to store packets to avoid race condition
  pcie_dll_base_seq_item     tx_queue [$];
  pcie_dll_base_seq_item     rx_queue [$];
  pcie_fc_pkt_counters_s  counters_queue[$];


  // Track RX DLLP ordering
  int unsigned rx_initfc1_order_step; // P->0, NP->1, Cpl->2
  int unsigned rx_initfc2_order_step; // P->0, NP->1, Cpl->2

  // Feature Ack Handshake tracking
  // Set to 1 the instant we drive our first DLLP_FEATURE_REQ (seen via Tx monitor)
  bit feat_dllp_sent;

  // Analysis implementation ports
  uvm_analysis_imp_tx        #(pcie_dll_base_seq_item, pcie_dll_scoreboard) tx_export;
  uvm_analysis_imp_rx        #(pcie_dll_base_seq_item, pcie_dll_scoreboard) rx_export;
  uvm_analysis_imp_state     #(pcie_dlcmsm_state_e,    pcie_dll_scoreboard) state_export;
  uvm_analysis_imp_counter   #(pcie_fc_pkt_counters_s, pcie_dll_scoreboard) counter_export; // counter item


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
    state_seeded  = 0;
    rx_initfc1_order_step    = 0;
    rx_initfc2_order_step    = 0;
    feat_dllp_sent   = 0;
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

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    forever begin
    wait (tx_queue.size() && rx_queue.size() && (counters_queue.size() || my_cfg.dlsm_state inside {DL_FEATURE_EXCH, DL_ACTIVE})) begin
      tx_item       = tx_queue.pop_front();
      rx_item       = rx_queue.pop_front();
      temp_counters = counters_queue.pop_front();


        prev_counters.counter_fc1  = curr_counters.counter_fc1;
        prev_counters.counter_fc2  = curr_counters.counter_fc2;
        curr_counters.counter_fc2  = temp_counters.counter_fc2; // = default value "0" if no counters "feature state"
        curr_counters.counter_fc1  = temp_counters.counter_fc1; // = default value "0" if no counters "feature state"
     

      // -------------- calling some common checks functions ------------------
      case (checks.proper_packets (rx_item, curr_state))
        0:  `uvm_error("SCOREBOARD", "ILLEGAL_DLLP: Violation invalid DLLP received!")
        1:  `uvm_error("SCOREBOARD", "ILLEGAL_TLP: Violation received TLP while Link is NOT ACTIVE!")
        2:  `uvm_info ("SCOREBOARD", "PROPER_PACKET: Valid packet received.", UVM_LOW) 
        default: ;
      endcase


      if (! checks.valid_VC (rx_item, curr_state))
          `uvm_error("SCOREBOARD", "VIRTUAL_CHANNEL: Violation Only credit advertisement DLLPs allowed for Virtual Channel 0 (VCO) during InitFC states!")


      case (checks.check_symmetric_active (rx_item, curr_state))
        0:  `uvm_fatal("SCOREBOARD", "ASYMMETRIC_ACTIVE: Violation both RC and EP don't reach active state symmetrically !!!")
        1:  `uvm_info ("SCOREBOARD", "SYMMETRIC_ACTIVE: Valid both RC and EP reached active state symmetrically!", UVM_LOW)
        default: ;
      endcase 


      if ($cast(rx_dllp_item, rx_item)) begin
          case (checks.Credit_Capture     (rx_item, curr_state, partner_cfg)) 
            0:  `uvm_error("SCOREBOARD", $sformatf("CREDIT_MISMATCH: Captured credits do not match expected values for type %s!", rx_dllp_item.dllp_type.name()))
            1:  `uvm_info ("SCOREBOARD", $sformatf("CREDIT_MATCH: Captured credits match expected values for type %s.", rx_dllp_item.dllp_type.name()), UVM_LOW)
            2:  `uvm_info ("SCOREBOARD", $sformatf("CREDIT_CAPTURE: Cannot capture credits."), UVM_LOW)
            default: ;
          endcase      

          case (checks.drop_packets      (my_cfg.dlsm_state, rx_item, rx_dllp_item,
                                         curr_counters, prev_counters)) 
            0:  `uvm_error("SCOREBOARD", "PKT_DROP: Violation abnormal behavior in state manager packet drop/increment logic!")
            1:  `uvm_info ("SCOREBOARD", "PKT_DROP: Valid Correct drop/increment behavior", UVM_LOW)
            default: ;
          endcase 
    end


  end 
end

  endtask

  // Called when the Tx monitor publishes a driven DLLP
  virtual function void write_tx(pcie_dll_base_seq_item item);
    pcie_dll_dllp_seq_item dllp_item;

    tx_queue.push_front(item);

    // Track that we have transmitted our Feature DLLP so the partner-side
    // ack handshake check can correctly validate feature_ack.
    if ($cast(dllp_item, item) && dllp_item.dllp_type == DLLP_FEATURE_REQ)
      feat_dllp_sent = 1;

    if (!$cast(dllp_item, item) && (my_cfg.dlsm_state != DL_ACTIVE)) begin // protocol violation
      `uvm_fatal("SCOREBOARD", "Traffic Isolation - Violation: TLP detected while Link is NOT ACTIVE!")
    end

  endfunction

  // Called when the Rx monitor publishes a received DLLP
  virtual function void write_rx(pcie_dll_base_seq_item item);
    pcie_dll_dllp_seq_item dllp_item;
    int unsigned next_order_step;
    string fatal_msg;

    rx_queue.push_front(item);

    if (!$cast(dllp_item, item)) begin
      if (!(my_cfg.dlsm_state inside {DL_INIT_FC2, DL_ACTIVE, DL_INACTIVE})) begin
        `uvm_fatal("SCOREBOARD", "Traffic Isolation - Violation: TLP detected while Link is NOT ACTIVE!")
      end
      else begin
        return ;
      end
    end


    // Feature DLLP Checks

    // Check: Reserved Fields Zero
    // Bits [22:1] of the Feature Supported field must be zero.
    // Check: Feature Ack Handshake — PARTNER side
    // The partner's feature_ack must equal feat_dllp_sent:
    //   - ack=1 while we haven't sent yet : partner is hallucinating a handshake
    //   - ack=0 after we have sent        : partner should be acking but is not
    if (dllp_item.dllp_type == DLLP_FEATURE_REQ) begin
      // Reserved bits check
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

      // Feature Ack Handshake check
      if (dllp_item.feature_ack && !feat_dllp_sent) begin
        fatal_msg = $sformatf(
          "SPEC VIOLATION (Feature Ack Handshake - PARTNER Rx): Partner sent feature_ack 1 but a Feature DLLP was never sent. Partner may only ack after we have transmitted our Feature DLLP.");
        `uvm_error("SCOREBOARD", fatal_msg)
      end else begin
        `uvm_info("SCOREBOARD",
          $sformatf("PASS (Feature Ack Handshake - PARTNER Rx): feature_ack=%0b == feat_dllp_sent=%0b.",
            rx_dllp_item.feature_ack, feat_dllp_sent), UVM_HIGH)
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

  endfunction

  // Called when the state manager update its counters due to receive packets
  virtual function void write_counter (pcie_fc_pkt_counters_s counters);
    counters_queue.push_front(counters);
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
        feat_dllp_sent = 0;
      end
      return;
    end

    // 1. Shift the history
    prev_state = curr_state;
    curr_state = new_state;

    if (curr_state == DL_INACTIVE) begin
      rx_initfc1_order_step  = 0;
      rx_initfc2_order_step  = 0;
      feat_dllp_sent = 0; // reset on link re-train so the handshake check stays valid
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