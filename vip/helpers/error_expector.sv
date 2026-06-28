class error_expector;

    
// -------------- Helper Function: to determine error status -------------
  static function pcie_dllp_error_e determine_error_status(pcie_dll_dllp_seq_item dllp_item);

      bit [31:0]          full_data = {dllp_item.dllp_type, dllp_item.dllp_payload};
      pcie_dlcmsm_state_e state     = dllp_item.current_state;

    `uvm_info("determine_error_status", $sformatf("----------------- the whole DLLP: %h ----------------", dllp_item.dllp), UVM_LOW)
    `uvm_info("determine_error_status", $sformatf("------------ DLLP type: %s & state: %s ---------------", dllp_item.dllp_type.name(), state.name()), UVM_LOW)
    `uvm_info("determine_error_status", $sformatf("---------------- verify CRC result: %b & correct CRC: %h -------------------", dllp_item.verify_crc(), pcie_dll_pkg::crc16_generator::calculate_dllp_crc(dllp_item.pack_data())), UVM_LOW)
    `uvm_info("determine_error_status", $sformatf("-------------------------- VC: %b -------------------------------", dllp_item.dllp_type[2:0]), UVM_LOW)
    `uvm_info("determine_error_status", $sformatf("---------------------- hdr_fc: %h & data_fc: %h -------------------", dllp_item.dllp_payload[21:14], dllp_item.dllp_payload[11:0]), UVM_LOW)
    
    // wrong CRC
    if (!(dllp_item.verify_crc())) begin
      //`uvm_info("determine_error_status", "------------------ DLLP with wrong CRC detected ------------------", UVM_LOW)
      return WRONG_CRC;
    end

    // invalid DLLP 
    else if (state == DL_FEATURE_EXCH && dllp_item.dllp_type != DLLP_FEATURE_REQ) begin
     // `uvm_info("determine_error_status", $sformatf("------------ Invalid DLLP type %s ------------", dllp_item.dllp_type.name()), UVM_LOW)
      return INVALID_DLLP;
    end
    else if ((state == DL_INIT_FC1) && !(dllp_item.dllp_type[7:3] inside {DLLP_INITFC1_P_VC, DLLP_INITFC1_NP_VC, DLLP_INITFC1_CPL_VC, DLLP_INITFC2_P_VC})) begin
     // `uvm_info("determine_error_status", $sformatf("------------ Invalid DLLP type %s ------------", dllp_item.dllp_type.name()), UVM_LOW)
      return INVALID_DLLP;
    end
    else if ((state == DL_INIT_FC2) && !(dllp_item.dllp_type[7:3] inside {DLLP_INITFC2_P_VC, DLLP_INITFC2_NP_VC, DLLP_INITFC2_CPL_VC})) begin
     // `uvm_info("determine_error_status", $sformatf("------------ Invalid DLLP type %s ------------", dllp_item.dllp_type.name()), UVM_LOW)
      return INVALID_DLLP;
    end
    /*TODO : maybe make it so we can handle more than the VC0 
    * and make it so we can handle the initialization of more than VC at the same time 
    * (maybe by adding a VC field to the state manager and the config)
    */
    // invalid VC (only InitFC DLLPs should be for VC0)
    else if (state inside {DL_INIT_FC1, DL_INIT_FC2} && dllp_item.dllp[2:0] != 3'b000) begin
      `uvm_info("determine_error_status", $sformatf("-------------------- Invalid VC: %b --------------------", dllp_item.dllp_type[2:0]), UVM_LOW)
      return INVALID_VC;
    end

    // errors free
    else begin
      `uvm_info("determine_error_status", "------------------ DLLP is error free ------------------", UVM_LOW)
      return ERROR_FREE;
    end

  endfunction

endclass : error_expector