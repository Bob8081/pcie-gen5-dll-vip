class pcie_dll_common_checks extends uvm_object;

  // TODO: remove redundant variables
  
  // registeration 
  `uvm_object_utils(pcie_dll_common_checks)

  // Configurations
  pcie_dll_partner_cfg  partner_cfg;
  pcie_dll_my_cfg       my_cfg;


  // all signals related checks "partner side"
    pcie_dll_dllp_seq_item rx_dllp_item;
    pcie_dll_tlp_seq_item  rx_tlp_item;

    pcie_dlcmsm_state_e rx_prev_state;
    pcie_dlcmsm_state_e rx_curr_state;
    pcie_dllp_type_e    rx_prev_dllp_type;
    pcie_dllp_type_e    rx_curr_dllp_type;

  // all signals related checks "Tx side"
    pcie_dll_dllp_seq_item tx_dllp_item;
    pcie_dll_tlp_seq_item  tx_tlp_item;
    
    pcie_dlcmsm_state_e tx_prev_state;
    pcie_dlcmsm_state_e tx_curr_state;
    pcie_dllp_type_e    tx_prev_dllp_type;
    pcie_dllp_type_e    tx_curr_dllp_type;

    int unsigned counter_fc1;
    int unsigned counter_fc2;
    int unsigned prev_st_count1;
    int unsigned prev_st_count2;


  pcie_fc_type_e         credit_type;
  bit                    no_capture_credits = 0; 

  bit                    tx_updated;
  bit                    rx_updated;
  bit                    counter_update;


  function void calling_common_checks();
    if (tx_updated && rx_updated && counter_update) begin

    case (rx_dllp_item.dllp_type[7:3])
        DLLP_INITFC1_P_VC   , DLLP_INITFC2_P_VC   : credit_type = FC_P;
        DLLP_INITFC1_NP_VC  , DLLP_INITFC2_NP_VC  : credit_type = FC_NP;
        DLLP_INITFC1_CPL_VC , DLLP_INITFC2_CPL_VC : credit_type = FC_CPL;
        default: begin
             no_capture_credits = 1'b1; // flag to indicate that we shouldn't capture credits from this DLLP
        end
    endcase

      // -------- scoreboard reporting -----------
      `uvm_info("SCOREBOARD", "----------- Both Tx and Rx items have been updated. Calling common checks... -----------", UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ Current Tx state: %s, Previous Tx state: %s ------", tx_curr_state.name(), tx_prev_state.name()), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ Current Rx state: %s, Previous Rx state: %s ------", rx_curr_state.name(), rx_prev_state.name()), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ Current Tx DLLP: %s, Previous Tx DLLP: %s ------", tx_curr_dllp_type.name(), tx_prev_dllp_type.name()), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ Current Rx DLLP type: %s, Previous Rx DLLP type: %s ------", rx_curr_dllp_type.name(), rx_prev_dllp_type.name()), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ virtual channel: %b ------", rx_dllp_item.dllp[2:0]), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ counter_fc1: %0d, counter_fc2: %0d ------", counter_fc1, counter_fc2), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ received_DLLP... HDR_FC: %0d, HDR_SCALE: %0d ------", rx_dllp_item.hdr_FC, rx_dllp_item.hdr_scale), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ partner_cfg... HDR_FC: %0d, HDR_SCALE: %0d ------", partner_cfg.partner_credits[credit_type].hdr_limit, partner_cfg.partner_credits[credit_type].hdr_scale), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ received_DLLP... DATA_FC: %0d, DATA_SCALE: %0d ------", rx_dllp_item.data_FC, rx_dllp_item.data_scale), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("------ partner_cfg... DATA_FC: %0d, DATA_SCALE: %0d ------", partner_cfg.partner_credits[credit_type].data_limit, partner_cfg.partner_credits[credit_type].data_scale), UVM_LOW)
      `uvm_info("SCOREBOARD", $sformatf("-----------------------------------------------------------------------------------"), UVM_LOW)

      traffic_isolation_check();
      check_symmetric_active();
      Credit_Capture();
      drop_packets();

      `uvm_info("SCOREBOARD", $sformatf("-----------------------------------------------------------------------------------"), UVM_LOW)

      tx_updated = 0;
      rx_updated = 0;
      counter_update = 0;
    end

  endfunction

  
    // ------ checks for DLLP items - to be called from write function in scoreboard ------

    // traffic_isolation check implementation...

    // note this function works for received DLLP items
    function void traffic_isolation_check (pcie_dll_dllp_seq_item dllp_item);

      //pcie_dll_dllp_seq_item dllp_item = rx_dllp_item;  

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

            DL_INIT_FC1, DL_INIT_FC2: begin // note: we remove virtual channel bits to separate between invalid dllp and invalid VC 
                if (!(dllp_item.dllp_type[7:3] inside {DLLP_INITFC1_P_VC, DLLP_INITFC1_NP_VC, DLLP_INITFC1_CPL_VC, DLLP_INITFC2_P_VC, DLLP_INITFC2_NP_VC, DLLP_INITFC2_CPL_VC})) begin
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

    function void drop_packets (pcie_dllp_type_e    current_dllp_type, pcie_dllp_type_e  prev_dllp_type,
                                int unsigned        current_st_count;, int unsigned      prev_st_count,
                                pcie_dlcmsm_state_e current_state);

        
        bit is_valid = 0; // A single flag to evaluate the entire logic

       /**  int unsigned        current_st_count;
        int unsigned        prev_st_count;
        pcie_dlcmsm_state_e current_state     = rx_curr_state;
        pcie_dllp_type_e    current_dllp_type = rx_curr_dllp_type;
        pcie_dllp_type_e    prev_dllp_type    = rx_prev_dllp_type; **/


        if (current_state inside {DL_INIT_FC1, DL_INIT_FC2}) begin

            if (current_state == DL_INIT_FC1) begin
              current_st_count = counter_fc1;
              prev_st_count    = prev_st_count1;
            end
            else begin
              current_st_count = counter_fc2;
              prev_st_count    = prev_st_count2;
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
            else if (   (rx_curr_state == DL_INIT_FC1 && rx_prev_state == DL_FEATURE_EXCH) && current_dllp_type inside {DLLP_INITFC1_NP, DLLP_INITFC1_CPL}
                      ||(current_dllp_type inside {DLLP_INITFC1_CPL } && prev_dllp_type inside {DLLP_INITFC1_P   })
                      ||(current_dllp_type inside {DLLP_INITFC1_P   } && prev_dllp_type inside {DLLP_INITFC1_NP  })
                      ||(current_dllp_type inside {DLLP_INITFC1_NP  } && prev_dllp_type inside {DLLP_INITFC1_CPL })
                      ||(rx_curr_state == DL_INIT_FC2 && rx_prev_state == DL_INIT_FC1)     && current_dllp_type inside {DLLP_INITFC2_NP, DLLP_INITFC2_CPL}
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

    endfunction : drop_packets


    // to check that both RC and EP reach active state symmetrically
    // TODO: need to make sure about its behavior
    function void check_symmetric_active (pcie_dlcmsm_state_e tx_prev_state, pcie_dlcmsm_state_e tx_curr_state
                                          pcie_dlcmsm_state_e rx_prev_state, pcie_dlcmsm_state_e rx_curr_state);

    if (tx_curr_state == DL_ACTIVE && rx_curr_state == DL_ACTIVE) begin
        `uvm_info("SCOREBOARD: SYMMETRIC_ACTIVE", "Valid: both RC and EP reached active state symmetrically!", UVM_LOW)
    end
    else if ( (tx_curr_state == DL_INACTIVE && tx_prev_state == DL_ACTIVE && !(rx_curr_state inside {DL_INACTIVE, DL_ACTIVE}) ) ||
              (rx_curr_state == DL_INACTIVE && rx_prev_state == DL_ACTIVE && !(tx_curr_state inside {DL_INACTIVE, DL_ACTIVE}) ) ) begin
        `uvm_fatal("SCOREBOARD: ASYMMETRIC_ACTIVE", "Violation: both RC and EP don't reach active state symmetrically!")
    end

endfunction : check_symmetric_active


// note: this function works for the received DLLP
function void Credit_Capture (pcie_dll_dllp_seq_item rx_dllp_item,
                              pcie_dll_partner_cfg   partner_cfg);

pcie_fc_type_e           credit_type;
bit                      no_capture_credits = 0; 


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


  // constructor
  function new(string name = "pcie_dll_common_checks");
    super.new(name);
  endfunction




endclass : pcie_dll_common_checks