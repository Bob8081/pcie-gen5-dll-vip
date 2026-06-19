class pcie_dll_common_checks extends uvm_object;
  //TODO : add checks for timing violation in initfc packets in recieving and transmitting
  //TODO : predict and check for current state

  `uvm_object_utils(pcie_dll_common_checks)

  // control signals
  bit  tx_updated;
  bit  rx_updated;
  bit  counter_update;

  function new(string name = "pcie_dll_common_checks");
    super.new(name);
  endfunction

  
  // DLCMSM State Transition Checks 

  /**
   * check_init_trigger
   * @brief Verify that DL_Inactive -> DL_Init transition occurs only after pl_lnk_up == 1
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param pl_lnk_up Link up status from PHY
   * @return 1 if check passes, 0 if check fails (FATAL)
   * @severity FATAL - Link must be UP before exiting DL_Inactive
   */
  function bit check_init_trigger(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit pl_lnk_up
  );
    bit is_init_transition = (prev_state == DL_INACTIVE) && 
                             ((curr_state == DL_FEATURE_EXCH) || 
                              (curr_state == DL_INIT_FC1));
    
    if (is_init_transition && !pl_lnk_up) begin
      return 0;
    end
    return 1;
  endfunction

  /**
   * check_valid_transition
   * @brief Verify that the DLCMSM follows the allowed Phase 1 sequence:
   *        DL_INACTIVE -> DL_FEATURE_EXCH -> DL_INIT_FC1 -> DL_INIT_FC2 -> DL_ACTIVE
   *        or DL_INACTIVE -> DL_INIT_FC1 -> DL_INIT_FC2 -> DL_ACTIVE
    *        or DL_ACTIVE -> DL_INACTIVE
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @return 1 if the transition is valid, 0 if it is illegal (FATAL)
   * @severity FATAL - Any deviation from the allowed state order is illegal
   */
  function bit check_valid_transition(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state
  );
    bit valid_transition;

    case (prev_state)
      DL_INACTIVE:     valid_transition = (curr_state == DL_FEATURE_EXCH) ||
                                          (curr_state == DL_INIT_FC1);
      DL_FEATURE_EXCH: valid_transition = (curr_state == DL_INIT_FC1);
      DL_INIT_FC1:     valid_transition = (curr_state == DL_INIT_FC2);
      DL_INIT_FC2:     valid_transition = (curr_state == DL_ACTIVE);
      DL_ACTIVE:       valid_transition = (curr_state == DL_INACTIVE);
      default:         valid_transition = 1'b0;
    endcase

    return valid_transition;
  endfunction

  /**
   * check_state_stability
   * @brief Verify that once the DLCMSM reaches DL_ACTIVE, it does not regress
   *        to DL_INIT_FC1 or DL_INACTIVE while pl_lnk_up remains high.
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param pl_lnk_up Link up status from PHY
   * @return 1 if the state remains stable, 0 if it regresses (FATAL)
   * @severity FATAL - DL_ACTIVE must not regress while link up is asserted
   */
  function bit check_state_stability(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit pl_lnk_up
  );
    bit regresses_from_active;

    regresses_from_active = (prev_state == DL_ACTIVE) && pl_lnk_up &&
                            ((curr_state == DL_INACTIVE) ||
                             (curr_state == DL_INIT_FC1));

    if (regresses_from_active) begin
      return 0;
    end

    return 1;
  endfunction

  /**
   * check_active_gate_fi1
   * @brief Verify that DL_INIT_FC1 -> DL_INIT_FC2 occurs only after FI1 is set.
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param fi1_set FI1 gate flag from state manager
   * @return 1 if the gate is satisfied, 0 if it is not (FATAL)
   * @severity FATAL - DL_INIT_FC2 requires FI1 to be asserted first
   */
  function bit check_active_gate_fi1(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit fi1_set
  );
    bit is_active_transition;

    is_active_transition = (prev_state == DL_INIT_FC1) && (curr_state == DL_INIT_FC2);

    if (is_active_transition && !fi1_set) begin
      return 0;
    end

    return 1;
  endfunction

  /**
   * check_active_gate_fi2
   * @brief Verify that DL_INIT_FC2 -> DL_ACTIVE occurs only after FI2 is set.
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param fi2_set FI2 gate flag from state manager
   * @return 1 if the gate is satisfied, 0 if it is not (FATAL)
   * @severity FATAL - DL_ACTIVE requires FI2 to be asserted first
   */
  function bit check_active_gate_fi2(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit fi2_set
  );
    bit is_active_transition;

    is_active_transition = (prev_state == DL_INIT_FC2) && (curr_state == DL_ACTIVE);

    if (is_active_transition && !fi2_set) begin
      return 0;
    end

    return 1;
  endfunction

  /**
   * check_fc_strict_order
   * @brief Verify that DLLPs are observed in strict order:
   *        expected_first, expected_second, expected_third.
   * @param dllp_type Observed DLLP type from the RX monitor
   * @param order_step Current ordering step (0, 1, 2, 3=done)
   * @param expected_first Expected type for step 0
   * @param expected_second Expected type for step 1
   * @param expected_third Expected type for step 2
   * @param next_order_step Updated ordering step after the current DLLP
   * @return 1 if the observed type matches the expected order, 0 otherwise
   * @severity ERROR - DLLPs must arrive in the exact expected order
   */
  function bit check_fc_strict_order(
    pcie_dllp_type_e dllp_type,
    int unsigned order_step,
    pcie_dllp_type_e expected_first,
    pcie_dllp_type_e expected_second,
    pcie_dllp_type_e expected_third,
    output int unsigned next_order_step
  );
    bit valid_order;

    next_order_step = order_step;
    valid_order = 1'b1;

    case (order_step)
      0: begin
        if (dllp_type == expected_first) begin
          next_order_step = 1;
        end else begin
          valid_order = 1'b0;
        end
      end

      1: begin
        if (dllp_type == expected_second) begin
          next_order_step = 2;
        end else begin
          valid_order = 1'b0;
        end
      end

      2: begin
        if (dllp_type == expected_third) begin
          next_order_step = 3;
        end else begin
          valid_order = 1'b0;
        end
      end

      default: begin
        next_order_step = 3;
      end
    endcase

    return valid_order;
  endfunction


  /**
   * check_feature_reserved_zero
   * @brief Verify that bits [22:1] of the received Feature Supported field are
   *        all zero. Only bit 0 (Scaled Flow Control) is a defined feature bit;
   *        all other bits are reserved and must be transmitted as zero by the
   *        partner (PCIe Base Spec Rev 5.0).
   * @param feature_support The 23-bit feature_support field from the received
   *        DLLP_FEATURE_REQ, as decoded by pcie_dll_dllp_seq_item::unpack().
   * @return 1 if bits [22:1] are all zero (check passes), 0 otherwise (ERROR)
   * @severity ERROR - Reserved bits must be zero; a non-zero value indicates
   *           a malformed or non-compliant Feature DLLP from the partner.
   */
  function bit check_feature_reserved_zero(
    bit [22:0] feature_support
  );
    // Mask out bit 0; the remaining bits [22:1] must all be zero.
    if (feature_support[22:1] != 22'b0) begin
      return 0;
    end
    return 1;
  endfunction

  /////////////////////////////////////// ----------------------------------- /////////////////////////////////

  // traffic_isolation check implementation...

    // note this function works for received DLLP items
    function void traffic_isolation_check (pcie_dll_dllp_seq_item dllp_item);


        // Only proper DLLPs are transmitted during states
        case (dllp_item.current_state)
            DL_FEATURE_EXCH: begin
                if (dllp_item.dllp_type != DLLP_FEATURE_REQ) begin
                    `uvm_error("SCOREBOARD: ILLEGAL_DLLP", "Violation: Only FEATURE_EXCH DLLPs allowed in FEATURE_EXCH state!")
                end
                else begin
                    `uvm_info("SCOREBOARD: PROPER_DLLP", "Valid: FEATURE_EXCH DLLP detected in FEATURE_EXCH state.", UVM_LOW)
                end
            end

            DL_INIT_FC1: begin // note: we remove virtual channel bits to separate between invalid dllp and invalid VC 
                if (!(dllp_item.dllp_type[7:3] inside {DLLP_INITFC1_P_VC, DLLP_INITFC1_NP_VC, DLLP_INITFC1_CPL_VC, DLLP_INITFC2_P_VC, DLLP_INITFC2_NP_VC, DLLP_INITFC2_CPL_VC})) begin
                    `uvm_error("SCOREBOARD: ILLEGAL_DLLP", "Violation: Only InitFC DLLPs allowed in INIT_FC states!")
                end
                else begin
                    `uvm_info("SCOREBOARD: PROPER_DLLP", "Valid: InitFC DLLP detected in INIT_FC state.", UVM_LOW)
                end
            end

            DL_INIT_FC2: begin // note: we remove virtual channel bits to separate between invalid dllp and invalid VC 
                if (!(dllp_item.dllp_type[7:3] inside {DLLP_INITFC2_P_VC, DLLP_INITFC2_NP_VC, DLLP_INITFC2_CPL_VC})) begin
                    `uvm_error("SCOREBOARD: ILLEGAL_DLLP", "Violation: Only InitFC DLLPs allowed in INIT_FC states!")
                end
                else begin
                    `uvm_info("SCOREBOARD: PROPER_DLLP", "Valid: InitFC DLLP detected in INIT_FC state.", UVM_LOW)
                end
            end
        endcase


        // All InitFC DLLPs are strictly addressed to Virtual Channel 0 (VCO).
        if (dllp_item.dllp_type[7:3] inside {DLLP_INITFC1_P_VC, DLLP_INITFC1_NP_VC, DLLP_INITFC1_CPL_VC, DLLP_INITFC2_P_VC, DLLP_INITFC2_NP_VC, DLLP_INITFC2_CPL_VC}) begin
            if (dllp_item.dllp_type[2:0] != 3'b000) begin // note: make sure this bits hit VC ID in DLLP header
                `uvm_error("SCOREBOARD: VIRTUAL_CHANNEL", "Violation: Only credit advertisement DLLPs allowed for Virtual Channel 0 (VCO) during InitFC states!")
            end
            else begin
                `uvm_info("SCOREBOARD: VIRTUAL_CHANNEL", "Valid: credit advertisement DLLPs is for Virtual Channel 0 (VCO) during InitFC states!", UVM_LOW)
            end
        end

    endfunction


// ------------------- DATA INTEGREITY CHECKS IMPLEMENTATIONS -------------------

    // to make sure that the state manager drops packets with ubnormal behavior
    // note: we check the behavior of state manager with the received packets
    // note: can be updated depends on the state manager implementation
    function void drop_packets (pcie_dllp_type_e    current_dllp_type, pcie_dllp_type_e  prev_dllp_type,
                                pcie_state_mgr_counters_s curr_counters,pcie_state_mgr_counters_s prev_counters, 
                                pcie_dlcmsm_state_e current_state, pcie_dlcmsm_state_e prev_state,
                                pcie_dll_dllp_seq_item rx_dllp_item);

        
        bit           is_valid = 0; // A single flag to evaluate the entire logic
        int unsigned  current_st_count;
        int unsigned  prev_st_count;

    if (rx_updated && counter_update) begin
        if (current_state inside {DL_INIT_FC1, DL_INIT_FC2}) begin

            if (current_state == DL_INIT_FC1) begin
              current_st_count = curr_counters.counter_fc1;
              prev_st_count    = prev_counters.counter_fc1;
            end
            else begin
              current_st_count = curr_counters.counter_fc2;
              prev_st_count    = prev_counters.counter_fc2;
            end
          
          
            // Error packet --> keep counter the same
            if (pcie_dll_pkg::error_expector::determine_error_status(rx_dllp_item) != ERROR_FREE) begin 
                        is_valid = (prev_st_count == current_st_count);
            end
            // repeated INITFC packets --> reset if 5 reptations
            else if (current_dllp_type == prev_dllp_type) begin // repeated initfc
                        is_valid = (prev_st_count == current_st_count);
            end
            // disorder INITFC packets --> zero
            else if (   (current_state == DL_INIT_FC1 && prev_state == DL_FEATURE_EXCH) && current_dllp_type inside {DLLP_INITFC1_NP, DLLP_INITFC1_CPL}
                      ||(current_dllp_type inside {DLLP_INITFC1_CPL } && prev_dllp_type inside {DLLP_INITFC1_P   })
                      ||(current_dllp_type inside {DLLP_INITFC1_P   } && prev_dllp_type inside {DLLP_INITFC1_NP  })
                      ||(current_dllp_type inside {DLLP_INITFC1_NP  } && prev_dllp_type inside {DLLP_INITFC1_CPL })
                      ||(current_state == DL_INIT_FC2 && prev_state == DL_INIT_FC1)     && current_dllp_type inside {DLLP_INITFC2_NP, DLLP_INITFC2_CPL}
                      ||(current_dllp_type inside {DLLP_INITFC2_CPL } && prev_dllp_type inside {DLLP_INITFC2_P   })
                      ||(current_dllp_type inside {DLLP_INITFC2_P   } && prev_dllp_type inside {DLLP_INITFC2_NP  })
                      ||(current_dllp_type inside {DLLP_INITFC2_NP  } && prev_dllp_type inside {DLLP_INITFC2_CPL }) ) begin
                        is_valid = (current_st_count == 0);
            end 

            // INITFC1 within INITFC2 --> reset
            else if (   (current_dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL} && prev_dllp_type inside {DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL}) ) begin
                        is_valid = (current_st_count == prev_st_count);
            end

            else begin // normal behavior
                    is_valid = (current_st_count == prev_st_count+1);
                end 
        end
        
        else begin // If the state is not INIT_FC no need to check state manager counter behavior
            is_valid = 1; 
        end


        if (is_valid) begin
            `uvm_info("SCOREBOARD: PKT_DROP", "Valid: Correct drop/increment behavior", UVM_LOW)
        end 
        else begin
            `uvm_error("SCOREBOARD: PKT_DROP", "Violation: abnormal behavior in state manager packet drop/increment logic!")
        end

    end

    endfunction : drop_packets


    // to check that both RC and EP reach active state symmetrically
    function void check_symmetric_active (pcie_dlcmsm_state_e tx_prev_state, pcie_dlcmsm_state_e tx_curr_state,
                                          pcie_dlcmsm_state_e rx_prev_state, pcie_dlcmsm_state_e rx_curr_state);

    if (tx_updated && rx_updated) begin
        if (tx_curr_state == DL_ACTIVE && rx_curr_state == DL_ACTIVE) begin
            `uvm_info("SCOREBOARD: SYMMETRIC_ACTIVE", "Valid: both RC and EP reached active state symmetrically!", UVM_LOW)
        end
        else if ( (tx_curr_state == DL_INACTIVE && tx_prev_state == DL_ACTIVE && !(rx_curr_state inside {DL_INACTIVE, DL_ACTIVE}) ) ||
                  (rx_curr_state == DL_INACTIVE && rx_prev_state == DL_ACTIVE && !(tx_curr_state inside {DL_INACTIVE, DL_ACTIVE}) ) ) begin
            `uvm_fatal("SCOREBOARD: ASYMMETRIC_ACTIVE", "Violation: both RC and EP don't reach active state symmetrically!")
        end
    end

endfunction : check_symmetric_active


// note: this function works for the received DLLP
function void Credit_Capture (pcie_dll_dllp_seq_item rx_dllp_item,
                              pcie_dll_partner_cfg   partner_cfg);

    pcie_fc_type_e  credit_type;
    bit             no_capture_credits = 0; 


    // Determine the credit type based on the DLLP type
    case (rx_dllp_item.dllp_type[7:3])
        DLLP_INITFC1_P_VC   , DLLP_INITFC2_P_VC   : credit_type = FC_P;
        DLLP_INITFC1_NP_VC  , DLLP_INITFC2_NP_VC  : credit_type = FC_NP;
        DLLP_INITFC1_CPL_VC , DLLP_INITFC2_CPL_VC : credit_type = FC_CPL;
        default: begin
             no_capture_credits = 1'b1; // flag to indicate that we shouldn't capture credits from this DLLP
        end
    endcase

    // compare the actual received credits with the stored credits from peer
    if (!no_capture_credits) begin
        if (   (rx_dllp_item.hdr_FC     != partner_cfg.partner_credits[credit_type].hdr_limit) 
             ||(rx_dllp_item.data_FC    != partner_cfg.partner_credits[credit_type].data_limit) 
             ||(rx_dllp_item.hdr_scale  != partner_cfg.partner_credits[credit_type].hdr_scale) 
             ||(rx_dllp_item.data_scale != partner_cfg.partner_credits[credit_type].data_scale) ) begin

            `uvm_error("SCOREBOARD:CREDIT_MISMATCH",$sformatf("Captured credits do not match expected values for type %s!", credit_type.name()))
        end 
        else begin
            `uvm_info("SCOREBOARD:CREDIT_MATCH", $sformatf("Captured credits match expected values for type %s.", credit_type.name()), UVM_LOW)
        end
    end

    else begin 
        `uvm_info("SCOREBOARD:CREDIT_CAPTURE", $sformatf("Received non-InitFC DLLP type %s. Cannot capture credits.", rx_dllp_item.dllp_type.name()), UVM_LOW)
    end 

endfunction : Credit_Capture


endclass : pcie_dll_common_checks