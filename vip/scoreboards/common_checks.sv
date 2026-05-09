class pcie_dll_common_checks extends uvm_object;
  //TODO : add checks for timing violation in initfc packets in recieving and transmitting
  //TODO : predict and check for current state
  `uvm_object_utils(pcie_dll_common_checks)

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
      `uvm_fatal("INIT_TRIGGER_FAIL",
        $sformatf("FATAL: State transition DL_INACTIVE -> %s occurred while pl_lnk_up=%0b. " +
                  "Link must be UP before entering DL_Init state.",
                  curr_state.name(), pl_lnk_up))
      return 0;
    end
    return 1;
  endfunction

endclass : pcie_dll_common_checks
