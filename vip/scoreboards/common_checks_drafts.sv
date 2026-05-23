// Q: do i need checks for both Tx and Rx paths? or just one of them is enough to cover the checks?

class pcie_dll_common_checks_drafts extends uvm_subscriber #(pcie_dll_base_seq_item);
  
  // registeration 
  `uvm_object_utils(pcie_dll_common_checks_drafts)

  pcie_dll_dynamic_cfg   cfg;
  pcie_fc_type_e         credit_type;
  
  pcie_dllp_type_e       prev_dllp_type;
  pcie_dllp_type_e       current_dllp_type;


  // Get config from uvm_config_db 
  // note: will be in scoreboard class not here
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pcie_dll_dynamic_cfg)::get(this, "", "dyn_cfg", cfg)) begin
      `uvm_fatal("CONFIG_ERR", "Could not get pcie_dll_dynamic_cfg from config_db")
    end
  endfunction

  virtual function void write(pcie_dll_base_seq_item item); // note: this will be scoreboard write function
    pcie_dll_dllp_seq_item dllp_item;
    pcie_dll_tlp_seq_item  tlp_item;

    if ($cast(dllp_item, item)) begin
        `uvm_info("COMMON_CHECKS", "DLLP Item Detected - Performing Common Checks...", UVM_LOW) 
        prev_dllp_type = current_dllp_type;
        current_dllp_type = dllp_item.dllp_type;
        
        traffic_isolation_check (dllp_item);
        data_integrity_check    (dllp_item, cfg);
        // TODO: add bob's checks here...
    end
    else if ($cast(tlp_item, item) && tlp_item.current_state != DL_ACTIVE) begin  
         `uvm_fatal("TRAFFIC_ISOLATION", "Violation: TLP detected while Link is NOT ACTIVE!")
    end

    endfunction


    // checks for DLLP items - to be called from write function in scoreboard

    // traffic_isolation check implementation...
    // note this function works for transmitted DLLP items
    function void traffic_isolation_check (pcie_dll_dllp_seq_item dllp_item);

        // Only proper DLLPs are transmitted during states
        case (dllp_item.current_state)
            DL_FEATURE_EXCH: begin
                if (dllp_item.dllp_type == DLLP_ACK) begin
                    `uvm_error("SB: TRAFFIC_ISOLATION", "Violation: Only FEATURE_EXCH DLLPs allowed in FEATURE_EXCH state!")
                end
                else begin
                    `uvm_info("SB: TRAFFIC_ISOLATION", "Valid: FEATURE_EXCH DLLP detected in FEATURE_EXCH state.", UVM_LOW)
                end
            end

            DL_INIT_FC1, DL_INIT_FC2: begin // note: we use ack to separate betweeninvalid dllp and invalid VC 
                if ((dllp_item.dllp_type == DLLP_ACK)) begin
                    `uvm_error("SB: TRAFFIC_ISOLATION", "Violation: Only InitFC DLLPs allowed in INIT_FC states!")
                end
                else begin
                    `uvm_info("SB: TRAFFIC_ISOLATION", "Valid: InitFC DLLP detected in INIT_FC state.", UVM_LOW)
                end
            end
        endcase


        // All InitFC DLLPs are strictly addressed to Virtual Channel 0 (VCO).
        if (dllp_item.dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL, DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL}) begin
            if (dllp_item.dllp_type[2:0] != 3'b000) begin // note: make sure this bits hit VC ID in DLLP header
                `uvm_error("SB: TRAFFIC_ISOLATION", "Violation: Only credit advertisement DLLPs allowed for Virtual Channel 0 (VCO) during InitFC states!")
            end
            else begin
                `uvm_info("SB: TRAFFIC_ISOLATION", "Valid: credit advertisement DLLPs is for Virtual Channel 0 (VCO) during InitFC states!", UVM_LOW)
            end
        end

    endfunction

 



// ------------------- DATA INTEGREITY CHECKS IMPLEMENTATIONS -------------------

    // to make sure that the state manager drops packets with ubnormal behavior
    // note: need to handle that its the recieved DLLP
    function void drop_packets (pcie_dll_dllp_seq_item dllp_item, pcie_dllp_type_e prev_dllp_type,
                                unsigned int current_st_count, unsigned int prev_st_count);

        
        bit is_valid = 0; // A single flag to evaluate the entire logic
        pcie_dlcmsm_state_e current_state  = dllp_item.current_state;
        pcie_dllp_type_e current_dllp_type = dllp_item.dllp_type;


        if (current_state inside {DL_INIT_FC1, DL_INIT_FC2}) begin
            // Error packet --> keep counter the same
            if (pcie_dll_pkg::error_status::determine_error_status(dllp_item) != ERROR_FREE) begin 
                        is_valid = (prev_st_count == current_st_count);
            end
            // repeated INITFC packets --> reset if 5 reptations
            else if (current_dllp_type == prev_dllp_type) begin // repeated initfc
                        is_valid = (prev_st_count == current_st_count);
            end
            // disorder INITFC packets --> zero
            else if (   (current_dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC2_P    } && prev_dllp_type inside {DLLP_INITFC1_NP, DLLP_INITFC2_NP  })
                      ||(current_dllp_type inside {DLLP_INITFC1_NP, DLLP_INITFC2_NP  } && prev_dllp_type inside {DLLP_INITFC1_CPL, DLLP_INITFC2_CPL}) 
                      ||(current_dllp_type inside {DLLP_INITFC1_CPL, DLLP_INITFC2_CPL} && prev_dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC2_P    }) ) begin
                        is_valid = (current_st_count == 0);
            end 
            else begin // normal behavior
                    is_valid = (current_st_count == prev_st_count+1);
                end 
        end
        
        else begin // If the state is not INIT_FC no need to check state manager counter behavior
            is_valid = 1; 
        end


        if (is_valid) begin
            `uvm_info("PKT_DROP", "Valid: Correct drop/increment behavior", UVM_LOW)
        end 
        else begin
            `uvm_error("PKT_DROP", "Violation: abnormal behavior in state manager packet drop/increment logic!")
        end

    endfunction : drop_packets


    // to check that both RC and EP reach active state symmetrically
    // TODO: need to make sure about its behavior
    function void check_symmetric_active (pcie_dlcmsm_state_e RC_current_state, pcie_dlcmsm_state_e RC_prev_state,
                                          pcie_dlcmsm_state_e EP_current_state, pcie_dlcmsm_state_e EP_prev_state);


    if (RC_current_state == DL_ACTIVE && EP_current_state == DL_ACTIVE) begin
        `uvm_info("symmetric_active", "Valid: both RC and EP reached active state symmetrically!", UVM_LOW)
    end
    else if (RC_current_state == DL_INACTIVE && RC_prev_state == DL_ACTIVE && EP_current_state != DL_ACTIVE) begin
        `uvm_fatal("symmetric_active", "Violation: both RC and EP don't reach active state symmetrically!")
    end
    else if (EP_current_state == DL_INACTIVE && EP_prev_state == DL_ACTIVE && RC_current_state != DL_ACTIVE) begin
        `uvm_fatal("symmetric_active", "Violation: both RC and EP don't reach active state symmetrically!")
    end

endfunction : check_symmetric_active


// note: it's this function works for the received DLLP
function void Credit_Capture (pcie_dll_dynamic_cfg dynamic_cfg, pcie_dll_dllp_seq_item rx_dllp_item);

pcie_fc_credits_values_s peer_credit     [pcie_fc_type_e] = dynamic_cfg.partner_credits; // this is the array of structs that contains the dynamic cfg credits values for each type
pcie_fc_type_e           credit_type;
bit                      no_capture_credits = 0; 

    // Determine the credit type based on the DLLP type
    case (rx_dllp_item.dllp_type)
        DLLP_INITFC1_P   , DLLP_INITFC2_P   : credit_type = FC_POSTED;
        DLLP_INITFC1_NP  , DLLP_INITFC2_NP  : credit_type = FC_NON_POSTED;
        DLLP_INITFC1_CPL , DLLP_INITFC2_CPL : credit_type = FC_CPL;
        default: begin
             no_capture_credits = 1'b1; // flag to indicate that we shouldn't capture credits from this DLLP
        end
    endcase


    // compare the actual received credits with the stored credits from peer
    if (!no_capture_credits) begin
        if (   (rx_dllp_item.hdr_limit  != peer_credit[credit_type].hdr_limit) 
             ||(rx_dllp_item.data_limit != peer_credit[credit_type].data_limit) 
             ||(rx_dllp_item.hdr_scale  != peer_credit[credit_type].hdr_scale) 
             ||(rx_dllp_item.data_scale != peer_credit[credit_type].data_scale) ) begin

            `uvm_error("CRD_MISMATCH",$sformatf("Captured credits do not match expected values for type %s!", credit_type.name()))
        end 
        else begin
            `uvm_info("CRD_MATCH", $sformatf("Captured credits match expected values for type %s.", credit_type.name()), UVM_LOW)
        end
    end

    else begin 
        `uvm_info("CRD_ERR", $sformatf("Received non-InitFC DLLP type %s. Cannot capture credits.", rx_dllp_item.dllp_type.name()), UVM_LOW)
    end

endfunction : Credit_Capture


  // constructor
  function new(string name = "pcie_dll_common_checks_drafts");
    super.new(name);
  endfunction




endclass : pcie_dll_common_checks_drafts