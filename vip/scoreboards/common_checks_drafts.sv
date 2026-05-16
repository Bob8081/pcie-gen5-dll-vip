// Q: do i need checks for both Tx and Rx paths? or just one of them is enough to cover the checks?

class pcie_dll_common_checks_drafts extends uvm_subscriber #(pcie_dll_base_seq_item);
  
  // registeration 
  `uvm_object_utils(pcie_dll_common_checks_drafts)

  pcie_dll_env_cfg   cfg;

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
        traffic_isolation_check (dllp_item);
        data_integrity_check    (dllp_item, cfg);
        // TODO: add bob's checks here...
    end
    else if ($cast(tlp_item, item)) begin  
         `uvm_fatal("TRAFFIC_ISOLATION", "Violation: TLP detected while Link is NOT ACTIVE!")
    end

    endfunction


    // checks for DLLP items - to be called from write function in scoreboard

    // traffic_isolation check implementation...
    function void traffic_isolation_check (pcie_dll_dllp_seq_item dllp_item);

        // Only proper DLLPs are transmitted during states
        case (dllp_item.current_state)
            DL_FEATURE_EXCH: begin
                if (dllp_item.dllp_type != DLLP_FEATURE_EXCH) begin
                    `uvm_error("TRAFFIC_ISOLATION", "Violation: Only FEATURE_EXCH DLLPs allowed in FEATURE_EXCH state!")
                end
                else begin
                    `uvm_info("TRAFFIC_ISOLATION", "Valid: FEATURE_EXCH DLLP detected in FEATURE_EXCH state.", UVM_LOW)
                end
            end

            DL_INIT_FC1, DL_INIT_FC2: begin
                if (!(dllp_item.dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL, DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL})) begin
                    `uvm_error("TRAFFIC_ISOLATION", "Violation: Only InitFC DLLPs allowed in INIT_FC states!")
                end
                else begin
                    `uvm_info("TRAFFIC_ISOLATION", "Valid: InitFC DLLP detected in INIT_FC state.", UVM_LOW)
                end
            end
        endcase


        // All InitFC DLLPs are strictly addressed to Virtual Channel 0 (VCO).
        if (dllp_item.current_state inside {DL_INIT_FC1, DL_INIT_FC2}) begin
            if (dllp_item.dllp_type[2:0] != 3'b000) begin // note: make sure this bits hit VC ID in DLLP header
                `uvm_error("TRAFFIC_ISOLATION", "Violation: Only credit advertisement DLLPs allowed for Virtual Channel 0 (VCO) during InitFC states!")
            end
            else begin
                `uvm_info("TRAFFIC_ISOLATION", "Valid: credit advertisement DLLPs is for Virtual Channel 0 (VCO) during InitFC states!", UVM_LOW)
            end
        end

    endfunction

    
    
    
    // TODO
    function void data_integrity_check (pcie_dll_dllp_seq_item dllp_item, pcie_dll_env_cfg cfg, unsigned int st_count);
        

        // signals advertised credits in Tx InitFC1
        bit [1:0]          hdr_scale_p   = cfg.init_fc_hdr_scale_p;
        bit [7:0]          hdr_fc_p      = cfg.init_fc_hdr_p;
        bit [1:0]          data_scale_p  = cfg.init_fc_data_scale_p;
        bit [11:0]         data_fc_p     = cfg.init_fc_data_p;
        bit [1:0]          hdr_scale_np  = cfg.init_fc_hdr_scale_np;
        bit [7:0]          hdr_fc_np     = cfg.init_fc_hdr_np;
        bit [1:0]          data_scale_np = cfg.init_fc_data_scale_np;
        bit [11:0]         data_fc_np    = cfg.init_fc_data_np;
        bit [1:0]          hdr_scale_cpl = cfg.init_fc_hdr_scale_cpl;
        bit [7:0]          hdr_fc_cpl    = cfg.init_fc_hdr_cpl;
        bit [1:0]          data_scale_cpl= cfg.init_fc_data_scale_cpl;
        bit [11:0]         data_fc_cpl   = cfg.init_fc_data_cpl;

        // signals to get correct CRC
        bit  [31:0]       full_data      = {dllp_item.dllp_type, dllp_item.dllp_payload}; 
        bit  [15:0]       correct_crc    = pcie_dll_pkg::crc16_generator::calculate_dllp_crc(full_data);

        // counter to track number of InitFC1 packets sent in Tx path
        unsigned int sb_count ;

        // TODO: data integrity checks "CRC ERROR drops & symmetric active" ...



        // make sure Initial credit values advertised in Tx InitFC1 match the initialized counters in the peer's state manager.
        case (dllp_item.dllp_type)
            DLLP_INITFC1_P, DLLP_INITFC2_P: begin
                if ( (dllp_item.hdr_scale == hdr_scale_p) && (dllp_item.hdr_FC == hdr_fc_p) && (dllp_item.data_scale == data_scale_p) && (dllp_item.data_FC == data_fc_p) ) begin
                    `uvm_info("DATA_INTEGRITY", "Tx InitFC1_P Credit match: Configured values match peer's State Manager", UVM_LOW)          
                end
                else begin
                    `uvm_error("DATA_INTEGRITY", "Tx InitFC1_P Credit Mismatch: Configured values do not match peer's State Manager!")
                end
            end

            DLLP_INITFC1_NP, DLLP_INITFC2_NP: begin
                if ( (dllp_item.hdr_scale == hdr_scale_np) && (dllp_item.hdr_FC == hdr_fc_np) && (dllp_item.data_scale == data_scale_np) && (dllp_item.data_FC == data_fc_np) ) begin
                    `uvm_info("DATA_INTEGRITY", "Tx InitFC1_NP Credit match: Configured values match peer's State Manager", UVM_LOW)          
                end
                else begin
                    `uvm_error("DATA_INTEGRITY", "Tx InitFC1_NP Credit Mismatch: Configured values do not match peer's State Manager!")
                end
            end

            DLLP_INITFC1_CPL, DLLP_INITFC2_CPL: begin
                if ( (dllp_item.hdr_scale == hdr_scale_cpl) && (dllp_item.hdr_FC == hdr_fc_cpl) && (dllp_item.data_scale == data_scale_cpl) && (dllp_item.data_FC == data_fc_cpl) ) begin
                    `uvm_info("DATA_INTEGRITY", "Tx InitFC1_CPL Credit match: Configured values match peer's State Manager", UVM_LOW)          
                end
                else begin
                    `uvm_error("DATA_INTEGRITY", "Tx InitFC1_CPL Credit Mismatch: Configured values do not match peer's State Manager!")
                end
            end
        endcase

    endfunction

  // constructor
  function new(string name = "pcie_dll_common_checks_drafts");
    super.new(name);
  endfunction




endclass : pcie_dll_common_checks_drafts
