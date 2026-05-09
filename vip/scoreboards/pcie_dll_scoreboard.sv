// Declare a specific imp suffix for the state port
`uvm_analysis_imp_decl(_state)

class pcie_dll_scoreboard extends uvm_scoreboard;
  
  pcie_dll_role_e role;

  // Track states
  pcie_dlcmsm_state_e prev_state;
  pcie_dlcmsm_state_e curr_state;

  // Analysis implementation for state transitions
  uvm_analysis_imp_state #(pcie_dlcmsm_state_e, pcie_dll_scoreboard) state_export;

  // Handle to common checks
  pcie_dll_common_checks checks;

  `uvm_component_utils(pcie_dll_scoreboard)

  function new(string name = "pcie_dll_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    curr_state = DL_INACTIVE;
    prev_state = DL_INACTIVE;
    state_export = new("state_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    checks = pcie_dll_common_checks::type_id::create("checks");
  endfunction
  
  // This function is called automatically when the state_mgr writes to the port
  virtual function void write_state(pcie_dlcmsm_state_e new_state);
    // 1. Shift the history
    prev_state = curr_state;
    curr_state = new_state;

    // 2. Perform state transition checks
    // TODO:  Need a way to pass pl_lnk_up and initfc flags to checks 
    
    // checks.check_init_trigger(prev_state, curr_state, pl_lnk_up);
  endfunction
  
endclass : pcie_dll_scoreboard
