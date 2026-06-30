class pcie_dll_common_checks extends uvm_object;
  //TODO : add checks for timing violation in initfc packets in recieving and transmitting
  //TODO : predict and check for current state
  //TODO : add checks for the feature state correct transition
  
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
  //TODO : to be revisited 
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


  /**
   * check_feature_ack_handshake
   * @brief Verify that the Feature Ack bit in a transmitted/received
   *        DLLP_FEATURE_REQ equals the Remote Data Link Feature Supported
   *        Valid bit (PCIe Base Spec Rev 5.0).
   *
   *        The spec mandates strict equality: a device sets feature_ack=1
   *        if and only if it has already received a valid Feature DLLP from
   *        its partner.  Setting ack=1 before that happens is a protocol
   *        violation; leaving ack=0 after receiving is also non-compliant.
   *
   * @param feature_ack          The feature_ack bit from the DLLP under test.
   * @param remote_feature_valid 1 if the sender has already received a valid
   *                             Feature DLLP from its peer; 0 otherwise.
   * @return 1 if feature_ack == remote_feature_valid (check passes),
   *         0 if they differ (ERROR)
   * @severity ERROR
   */
  function bit check_feature_ack_handshake(
    bit feature_ack,
    bit remote_feature_valid
  );
    if (feature_ack !== remote_feature_valid) begin
      return 0;
    end
    return 1;
  endfunction

  /////////////////////////////////////// ----------------------------------- /////////////////////////////////

  // traffic_isolation check implementation...

    // note this function works for received DLLP items
    function int proper_packets (pcie_dll_base_seq_item  item,
                                pcie_dlcmsm_state_e     tx_state);

      pcie_dllp_error_e     error_status;
      error_status= pcie_dll_pkg::error_expector::rx_determine_error_status(item, tx_state);

        // Only proper DLLPs are transmitted during states
      
        if (error_status == INVALID_DLLP) begin
          return 0;
          //`uvm_error("SCOREBOARD: ILLEGAL_DLLP", "Violation: invalid DLLP received!")
        end
        else if (error_status == INVALID_TLP) begin
          return 1;
          //`uvm_error("SCOREBOARD: ILLEGAL_TLP", "Violation: received TLP while Link is NOT ACTIVE!")
        end
        else begin
          return 2;
          //`uvm_info("SCOREBOARD: PROPER_DLLP", "Valid: valid packet received.", UVM_LOW)
        end


    endfunction


    function bit valid_VC (pcie_dll_base_seq_item  item,
                          pcie_dlcmsm_state_e     tx_state);

      pcie_dllp_error_e     error_status;
      error_status= pcie_dll_pkg::error_expector::rx_determine_error_status(item, tx_state);

        // All InitFC DLLPs are strictly addressed to Virtual Channel 0 (VCO).
        if (error_status == INVALID_VC) begin
          return 0; // error
          //`uvm_error("SCOREBOARD: VIRTUAL_CHANNEL", "Violation: Only credit advertisement DLLPs allowed for Virtual Channel 0 (VCO) during InitFC states!")
        end
        else begin
          return 1;
          //`uvm_info("SCOREBOARD: VIRTUAL_CHANNEL", "Valid: credit advertisement DLLPs is for Virtual Channel 0 (VCO) during InitFC states!", UVM_LOW)
        end

    endfunction


// ------------------- DATA INTEGREITY CHECKS IMPLEMENTATIONS -------------------

    // to make sure that the state manager drops packets with ubnormal behavior
    // note: we check the behavior of state manager with the received packets
    function int drop_packets (pcie_dllp_type_e  current_dllp_type,
                                pcie_dlcmsm_state_e tx_state, pcie_dll_base_seq_item  item,
                                pcie_state_mgr_counters_s curr_counters, 
                                pcie_state_mgr_counters_s prev_counters);

        
        int unsigned          is_valid; // A single flag to evaluate the entire logic
        int unsigned          current_st_count;
        int unsigned          prev_st_count;

        pcie_dllp_error_e     error_status;
        error_status = pcie_dll_pkg::error_expector::rx_determine_error_status(item, tx_state);
    
            if (tx_state == DL_INIT_FC1) begin
              current_st_count = curr_counters.counter_fc1;
              prev_st_count    = prev_counters.counter_fc1;
            end
            else if (tx_state == DL_INIT_FC2) begin
              current_st_count = curr_counters.counter_fc2;
              prev_st_count    = prev_counters.counter_fc2;
            end
          
          
            // Error packet
            is_valid = 2;
            if (error_status != ERROR_FREE) begin 
                  if (error_status == WRONG_CRC)
                        is_valid = (prev_st_count == current_st_count);
                  else if (error_status inside {INVALID_DLLP, INVALID_VC})
                        is_valid = (current_st_count == 0);
            end
            else begin // error free case
                        is_valid = (current_st_count == prev_st_count+1);
            end


      /** if (is_valid) begin
            `uvm_info("SCOREBOARD: PKT_DROP", "Valid: Correct drop/increment behavior", UVM_LOW)
        end 
        else begin
            `uvm_error("SCOREBOARD: PKT_DROP", "Violation: abnormal behavior in state manager packet drop/increment logic!")
        end **/

        return is_valid;

    endfunction : drop_packets


    // to check that both RC and EP reach are symmetric
    function int check_symmetric_active (pcie_dll_base_seq_item  item, pcie_dlcmsm_state_e tx_state);

      pcie_dll_dllp_seq_item  dllp_item;
      pcie_dll_tlp_seq_item   tlp_item;

      int tx_path_state, rx_path_state; // inactive=0, feature=1, initfc1=2, initfc2=3, active=4
      int delta; // differece between tx state and rx state

      pcie_dllp_error_e     error_status;
      error_status = pcie_dll_pkg::error_expector::rx_determine_error_status(item, tx_state);

      // covert Tx state to an integer
      case (tx_state)
        DL_INACTIVE     : tx_path_state = 0;
        DL_FEATURE_EXCH : tx_path_state = 1;
        DL_INIT_FC1     : tx_path_state = 2; 
        DL_INIT_FC2     : tx_path_state = 3;  
        DL_ACTIVE       : tx_path_state = 4;
        default:;
      endcase  

      if ($cast(dllp_item, item)) begin // DLLP item

        // determine its expected state as an integer
        case (dllp_item.dllp_type)
          DLLP_FEATURE_REQ:                                   rx_path_state = 1;
          DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL:  rx_path_state = 2;
          DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL:  rx_path_state = 3;
          default : ;
        endcase
      end

      else if ($cast(tlp_item, item)) begin
        rx_path_state = 4;
      end

      delta = tx_path_state - rx_path_state;

        if (error_status != INVALID_DLLP) begin
          if ((tx_path_state == 4 || rx_path_state == 4)) begin
           if (!(delta inside {1,0,-1})) begin
            return 0; // error
            //`uvm_fatal("SCOREBOARD: ASYMMETRIC_ACTIVE", "Violation: both RC and EP don't reach active state symmetrically !!!")
           end
           else begin
            return 1; // normal
            //`uvm_info("SCOREBOARD: SYMMETRIC_ACTIVE", "Valid: both RC and EP reached active state symmetrically!", UVM_LOW)
           end
          end
        end
        return 2;

endfunction : check_symmetric_active


// note: this function works for the received DLLP
function int Credit_Capture (pcie_dll_base_seq_item  item, pcie_dlcmsm_state_e tx_state,
                              pcie_dll_partner_cfg   partner_cfg);

    pcie_fc_type_e          credit_type;
    bit                     no_capture_credits = 0; 
    pcie_dll_dllp_seq_item  rx_dllp_item;

    pcie_dllp_error_e     error_status;
    error_status = pcie_dll_pkg::error_expector::rx_determine_error_status(item, tx_state);

if (error_status != INVALID_VC) begin  
  if ($cast(rx_dllp_item, item)) begin
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

              return 0; // error
            //`uvm_error("SCOREBOARD:CREDIT_MISMATCH",$sformatf("Captured credits do not match expected values for type %s!", credit_type.name()))
        end 
        else begin
             return 1; // normal
            //`uvm_info("SCOREBOARD:CREDIT_MATCH", $sformatf("Captured credits match expected values for type %s.", credit_type.name()), UVM_LOW)
        end
    end

    else begin 
      return 2;
       // `uvm_info("SCOREBOARD:CREDIT_CAPTURE", $sformatf("Received non-InitFC DLLP type %s. Cannot capture credits.", rx_dllp_item.dllp_type.name()), UVM_LOW)
    end 

  end
end
    else begin 
      return 2;
       // `uvm_info("SCOREBOARD:CREDIT_CAPTURE", $sformatf("Received non-InitFC DLLP type %s. Cannot capture credits.", rx_dllp_item.dllp_type.name()), UVM_LOW)
    end 


endfunction : Credit_Capture


endclass : pcie_dll_common_checks