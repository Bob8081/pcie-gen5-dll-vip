// Declare a specific imp suffix for the state port
`uvm_analysis_imp_decl(_state)

`uvm_analysis_imp_decl(_tx)
`uvm_analysis_imp_decl(_rx)

class pcie_dll_scoreboard extends uvm_scoreboard;
  
  pcie_dll_role_e role;

   // Configurations
  pcie_dll_partner_cfg  partner_cfg;
  pcie_dll_my_cfg       my_cfg;


  // Analysis implementation for state transitions
  //uvm_analysis_imp_state #(pcie_dlcmsm_state_e, pcie_dll_scoreboard) state_export;
  uvm_analysis_imp_tx    #(pcie_dll_base_seq_item, pcie_dll_scoreboard) tx_export; // my item
  uvm_analysis_imp_rx    #(pcie_dll_base_seq_item, pcie_dll_scoreboard) rx_export; // partner item


  // Handle to common checks
  pcie_dll_common_checks checks;

  `uvm_component_utils(pcie_dll_scoreboard)

  function new(string name = "pcie_dll_scoreboard", uvm_component parent = null);
    super.new(name, parent);

    //state_export = new("state_export", this);
    tx_export = new("tx_export", this);
    rx_export = new("rx_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get config from uvm_config_db 
    if (!uvm_config_db#(pcie_dll_partner_cfg)::get(this, "", "dyn_cfg", partner_cfg)) begin
      `uvm_fatal("CONFIG_ERR", "Could not get pcie_dll_partner_cfg from config_db")
    end

    if (!uvm_config_db#(pcie_dll_my_cfg)::get(this, "", "my_cfg", my_cfg)) begin
      `uvm_fatal("CONFIG_ERR", "Could not get pcie_dll_my_cfg from config_db")
    end

    checks = pcie_dll_common_checks::type_id::create("checks");
    checks.partner_cfg = partner_cfg;
    checks.my_cfg = my_cfg;
  endfunction
  
  // This function is called automatically when the state_mgr writes to the port
  //virtual function void write_state(pcie_dlcmsm_state_e new_state);
    // 1. Shift the history
    //tx_prev_state = tx_curr_state;
    //tx_curr_state = new_state;
    

    // 2. Perform state transition checks
    // TODO:  Need a way to pass pl_lnk_up and initfc flags to checks 
    
    // checks.check_init_trigger(prev_state, curr_state, pl_lnk_up);
  //endfunction

  virtual function void write_tx(pcie_dll_base_seq_item tx_item);
    pcie_dll_dllp_seq_item tx_dllp_item;
    pcie_dll_tlp_seq_item  tx_tlp_item;

    if ($cast(tx_dllp_item, tx_item)) begin
        `uvm_info("COMMON_CHECKS", "DLLP Item Detected - Performing Common Checks...", UVM_LOW) 
      
      // update cfg signals
        checks.tx_dllp_item      = tx_dllp_item;

        checks.tx_prev_state     = checks.tx_curr_state;
        checks.tx_curr_state     = tx_dllp_item.current_state;
        checks.tx_prev_dllp_type = checks.tx_curr_dllp_type;
        checks.tx_curr_dllp_type = tx_dllp_item.dllp_type;

  
        // TODO: call the checks functions here for transmitted DLLP items
        checks.tx_updated = 1'b1;
        checks.calling_common_checks();

    end
    else if ($cast(tx_tlp_item, tx_item) && tx_tlp_item.current_state != DL_ACTIVE) begin  
         `uvm_fatal("TRAFFIC_ISOLATION", "Violation: TLP detected while Link is NOT ACTIVE!")
    end
    else begin
      `uvm_info("COMMON_CHECKS", "transmitted TLP item detected in ACTIVE state", UVM_LOW)
      checks.tx_tlp_item   = tx_tlp_item;
      checks.tx_prev_state = checks.tx_curr_state;
      checks.tx_curr_state = DL_ACTIVE;
    end

    
  endfunction


  virtual function void write_rx(pcie_dll_base_seq_item rx_item);
    pcie_dll_dllp_seq_item rx_dllp_item;
    pcie_dll_tlp_seq_item  rx_tlp_item;

    if ($cast(rx_dllp_item, rx_item)) begin
        `uvm_info("COMMON_CHECKS", "DLLP Item Detected - Performing Common Checks...", UVM_LOW) 

      // update cfg signals

        checks.rx_dllp_item      = rx_dllp_item;
  
        checks.rx_prev_state     = checks.rx_curr_state;
        checks.rx_curr_state     = rx_dllp_item.current_state;
        checks.rx_prev_dllp_type = checks.rx_curr_dllp_type;
        checks.rx_curr_dllp_type = rx_dllp_item.dllp_type;

        checks.prev_st_count1  = checks.counter_fc1;
        checks.prev_st_count2  = checks.counter_fc2;
        checks.counter_fc1     = my_cfg.counter_fc1;
        checks.counter_fc2     = my_cfg.counter_fc2;
       

        // TODO: call the checks functions here for received DLLP items
        checks.rx_updated = 1'b1;
        checks.calling_common_checks();

    end
    else if ($cast(rx_tlp_item, rx_item) && rx_tlp_item.current_state != DL_ACTIVE) begin  
         `uvm_fatal("TRAFFIC_ISOLATION", "Violation: TLP detected while Link is NOT ACTIVE!")
    end
    else begin
      `uvm_info("COMMON_CHECKS", "received TLP item in ACTIVE state", UVM_LOW)
      checks.rx_tlp_item   = rx_tlp_item;
      checks.rx_prev_state = checks.rx_curr_state;
      checks.rx_curr_state = DL_ACTIVE;
    end

    
  endfunction
  
endclass : pcie_dll_scoreboard