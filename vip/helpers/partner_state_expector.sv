class partner_state_expector;

  static pcie_dlcmsm_state_e prev_state [string] = '{default: DL_INACTIVE}; // to contain RC & EP previous states

   static function pcie_dlcmsm_state_e get_rx_current_state (pcie_dllp_type_e dllp_type, string path);
    
    // note: receive TLP state handled in Rx monitor
    
     pcie_dlcmsm_state_e current_state;

    if (dllp_type == DLLP_FEATURE_REQ) begin
      current_state = DL_FEATURE_EXCH;
    end
    else if (dllp_type[7:3] inside {DLLP_INITFC1_P_VC, DLLP_INITFC1_NP_VC, DLLP_INITFC1_CPL_VC}) begin
      current_state = DL_INIT_FC1;
    end
    else if (dllp_type[7:3] inside {DLLP_INITFC2_P_VC, DLLP_INITFC2_NP_VC, DLLP_INITFC2_CPL_VC}) begin
      current_state = DL_INIT_FC2;
    end
    else  begin
      current_state = prev_state[path];
    end

    prev_state[path] = current_state;
    return current_state;
  endfunction


endclass : partner_state_expector