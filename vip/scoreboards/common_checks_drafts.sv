// Q: do i need checks for both Tx and Rx paths? or just one of them is enough to cover the checks?

class pcie_dll_common_checks_drafts extends uvm_subscriber #(pcie_dll_base_seq_item);
  
  // registeration 
  `uvm_object_utils(pcie_dll_common_checks_drafts)

  pcie_dll_env_cfg   cfg;
  pcie_dllp_type_e   previous_dllp_type;
  pcie_dllp_type_e   current_dllp_type;

  // Get config from uvm_config_db 
  // note: will be in scoreboard class not here
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(pcie_dll_env_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("CONFIG_ERR", "Could not get pcie_dll_env_cfg from config_db")
    end
  endfunction

  virtual function void write(pcie_dll_base_seq_item item); // note: this will be scoreboard write function
    pcie_dll_dllp_seq_item dllp_item;
    pcie_dll_tlp_seq_item  tlp_item;

    if ($cast(dllp_item, item)) begin
        `uvm_info("COMMON_CHECKS", "DLLP Item Detected - Performing Common Checks...", UVM_LOW) 
        previous_dllp_type = current_dllp_type;
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

    
    
    // data_integrity check implementation...
    function void data_integrity_check (pcie_dll_dllp_seq_item dllp_item, unsigned int st_count, unsigned int sb_count);

        // counter to track number of InitFC1 packets sent in Tx path
        unsigned int sb_count ;

        // TODO: data integrity checks "CRC ERROR drops & symmetric active" ...
        if (sb_count != st_count) begin
            `uvm_error("SB: DATA_INTEGRITY", "Violation: packet not dropped")
        end
        else begin
            `uvm_info("SB: DATA_INTEGRITY", "Valid: No data integrity issues detected.", UVM_LOW)
        end


    endfunction











    // to count the number of packets and drops it in case of error
    function unsigned int drop_packets (pcie_dllp_type_e current_dllp_type, pcie_dllp_type_e previous_dllp_type, pcie_dlcmsm_state_e current_state, unsigned int sb_count);

        unsigned int count= sb_count;


        if (current_state inside {DL_INIT_FC1, DL_INIT_FC2}) begin
            if (pcie_dll_pkg::error_status::determine_error_status(dllp_item) != ERROR_FREE) begin 
                count= count;
            end
            // repeated INITFC packets
            else (current_dllp_type == previous_dllp_type) begin // repeated initfc
                count= count;
            end
            // disorder INITFC packets
            else (   (current_dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC2_P    } && previous_dllp_type inside {DLLP_INITFC1_NP, DLLP_INITFC2_NP  })
                   ||(current_dllp_type inside {DLLP_INITFC1_NP, DLLP_INITFC2_NP  } && previous_dllp_type inside {DLLP_INITFC1_CPL, DLLP_INITFC2_CPL}) 
                   ||(current_dllp_type inside {DLLP_INITFC1_CPL, DLLP_INITFC2_CPL} && previous_dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC2_P    }) ) begin

                count= count;   
            end
            else begin // normal behavior
                count= count+1;
            end
        end


        return count;

    endfunction


  // constructor
  function new(string name = "pcie_dll_common_checks_drafts");
    super.new(name);
  endfunction




endclass : pcie_dll_common_checks_drafts
