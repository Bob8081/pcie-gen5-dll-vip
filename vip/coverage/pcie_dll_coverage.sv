// ---- pcie_dll_coverage ----

`uvm_analysis_imp_decl(_state)
class pcie_dll_coverage extends uvm_subscriber #(pcie_dll_base_seq_item);


  // to recieve tghe current state of state manager
  uvm_analysis_imp_state #(pcie_dlcmsm_state_e, pcie_dll_coverage) state_export;

  // ---- UVM Factory Registration ----
  `uvm_component_utils(pcie_dll_coverage)

  // ---- Signals ----
  bit [47:0]          dllp;           
  bit [127:0]         tlp;
  bit [23:0]          dllp_payload;
  bit [15:0]          crc;            
  bit [47:0]          expected_dllp;  

  pcie_dlcmsm_state_e state;
  pcie_dllp_type_e    dllp_type;
  pcie_dllp_error_e   error_status;

  // ---- Covergroups ----

  // ---- 1. DLLP Coverage Group ----
  covergroup cg_dllp_transitions (string path_label);

    option.per_instance = 1;
    option.name         = path_label;
    option.comment      = " Detailed DLLP Analysis — state, type, errors, credits ";

    // -- State Machine --
    cp_state: coverpoint state {
      option.comment = " Tracks DL state machine transitions";
      bins old_device              = (DL_INACTIVE => DL_INIT_FC1 => DL_INIT_FC2 => DL_ACTIVE);
      bins modern_device           = (DL_INACTIVE => DL_FEATURE_EXCH => DL_INIT_FC1 => DL_INIT_FC2 => DL_ACTIVE);
      bins going_through_states [] = {DL_INACTIVE, DL_FEATURE_EXCH, DL_INIT_FC1, DL_INIT_FC2, DL_ACTIVE}; 
    }

    cp_dllp_type: coverpoint dllp_type {
      option.comment = " Covers specific PCIe DLLP packet types";
      bins feature_state   = {DLLP_FEATURE_REQ};
      bins init_state_1 [] = {DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL}; 
      bins init_state_2 [] = {DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL};
    }

    // Indicates if the DLLP is part of a credit flow (bit 0 = 1)
    cp_payload_bit0: coverpoint dllp_payload[0] { 
      bins scl_flow [] = {1'b0, 1'b1};
    }

    // -- Errors --
    cp_error_status: coverpoint error_status {
      option.comment = " cover different error injection and protocol violations";
      bins sent_tlp        = {SENT_TLP};
      bins invalid_dllp    = {INVALID_DLLP};
      bins wrong_crc       = {WRONG_CRC};
      bins invalid_vc      = {INVALID_VC};
      // TODO: bins invalid_credits = {INVALID_CREDITS};
      bins error_free      = {ERROR_FREE};
      
    }

    // -- Crosses --
    cr_scaled_fc: cross cp_dllp_type, cp_payload_bit0 {
      option.comment = " Ensures Scaled Flow Control feature exchange";
      ignore_bins scl_fc = !binsof(cp_dllp_type.feature_state);
    }

    cr_inv_dllp: cross cp_dllp_type, cp_error_status {
      option.comment = " Invalid DLLP scenarios during states";
      ignore_bins not_invalid_dllp = !binsof(cp_error_status.invalid_dllp) ;
    }

    cr_wrong_crc: cross cp_dllp_type, cp_error_status {
      option.comment = " Wrong CRC scenarios during states";
      ignore_bins not_wrong_crc = !binsof(cp_error_status.wrong_crc);
    }

    cr_invalid_vc: cross cp_dllp_type, cp_error_status {
      option.comment = " Invalid VC scenarios during states";
      ignore_bins not_invalid_vc = !binsof(cp_error_status.invalid_vc) || (!binsof(cp_dllp_type.init_state_1) && !binsof(cp_dllp_type.init_state_2));
    }
    

    // -- Init State Specifics --
    cp_initfc: coverpoint dllp_type {
      option.comment = " Tracks FC Init sequences — in-order, disorder, and repeated";
      bins initfc1_B2B         = (DLLP_INITFC1_P => DLLP_INITFC1_NP => DLLP_INITFC1_CPL);
      bins initfc1_disorder [] = (DLLP_INITFC1_P  => DLLP_INITFC1_CPL),
                                 (DLLP_INITFC1_NP  => DLLP_INITFC1_P),
                                 (DLLP_INITFC1_CPL => DLLP_INITFC1_NP);
      bins initfc1_repeated [] = (DLLP_INITFC1_P  => DLLP_INITFC1_P),
                                 (DLLP_INITFC1_NP  => DLLP_INITFC1_NP),
                                 (DLLP_INITFC1_CPL => DLLP_INITFC1_CPL);

      bins initfc2_B2B         = (DLLP_INITFC2_P => DLLP_INITFC2_NP => DLLP_INITFC2_CPL);
      bins initfc2_disorder [] = (DLLP_INITFC2_P  => DLLP_INITFC2_CPL),
                                 (DLLP_INITFC2_NP  => DLLP_INITFC2_P),
                                 (DLLP_INITFC2_CPL => DLLP_INITFC2_NP);
      bins initfc2_repeated [] = (DLLP_INITFC2_P  => DLLP_INITFC2_P),
                                 (DLLP_INITFC2_NP  => DLLP_INITFC2_NP),
                                 (DLLP_INITFC2_CPL => DLLP_INITFC2_CPL);

      bins initfc2_witin_initfc1 = (DLLP_INITFC1_P  => DLLP_INITFC2_CPL),
                                   (DLLP_INITFC1_P  => DLLP_INITFC2_NP),
                                   (DLLP_INITFC1_P  => DLLP_INITFC2_P),
                                   (DLLP_INITFC1_NP  => DLLP_INITFC2_P);
      bins initfc1_witin_initfc2 = (DLLP_INITFC2_P  => DLLP_INITFC1_NP),
                                   (DLLP_INITFC2_P  => DLLP_INITFC1_P),
                                   (DLLP_INITFC2_P  => DLLP_INITFC1_CPL),
                                   (DLLP_INITFC2_NP  => DLLP_INITFC1_P);
    }


    // -- zero Credit coverage --
    cp_data_credits: coverpoint dllp_payload[11:0] {
      bins no_data_credits = {12'd0};
    }

    cp_hdr_credits: coverpoint dllp_payload[21:14] {
      bins no_hdr_credits = {8'd0};
    }


    cr_zero_data_credits: cross cp_dllp_type, cp_data_credits {
      option.comment = " Checks zero data credit advertisement during Init states";
      ignore_bins zero_credit = !binsof(cp_dllp_type.init_state_1) && !binsof(cp_dllp_type.init_state_2);
    }

    cr_zero_hdr_credits: cross cp_dllp_type, cp_hdr_credits {
      option.comment = " Checks zero header credit advertisement during Init states";
      ignore_bins zero_credit = !binsof(cp_dllp_type.init_state_1) && !binsof(cp_dllp_type.init_state_2);
    }

  endgroup

  // ---- 2. TLP Coverage Group ----
  covergroup cg_tlp_transitions (string path_label);

    option.per_instance = 1;
    option.name         = path_label;
    option.comment      = " Tracks TLP transmission during DL states ";

    cp_tlp: coverpoint tlp {
      bins send_tlp = {128'hDEADBEEF_CAFEBABE_11223344_55667788};
    }

  endgroup

  // ---- Constructor ----
  function new(string name = "pcie_dll_coverage", uvm_component parent = null);
    super.new(name, parent);

    state_export = new("state_export", this);

    if (uvm_is_match("*tx*", name)) begin
      cg_dllp_transitions = new("Tx_path_dllp");
      cg_tlp_transitions  = new("Tx_path_tlp");
    end
    else begin
      cg_dllp_transitions = new("Rx_path_dllp");
      cg_tlp_transitions  = new("Rx_path_tlp");
    end
  endfunction


  // ---- Write for state updates ----
  virtual function void write_state(pcie_dlcmsm_state_e current_state);
    state = current_state;
  endfunction

  // ---- Write for sequence item ----
  virtual function void write(pcie_dll_base_seq_item t);
    pcie_dll_dllp_seq_item dllp_item;
    pcie_dll_tlp_seq_item  tlp_item;

    if ($cast(dllp_item, t)) begin
      dllp          = dllp_item.dllp;
      dllp_type     = dllp_item.dllp_type;
      dllp_payload  = dllp_item.dllp_payload;
      crc           = dllp_item.crc;
      expected_dllp = {dllp_type, dllp_payload, crc};

      error_status  = determine_error_status(dllp_item);

      cg_dllp_transitions.sample();
    end
    else if ($cast(tlp_item, t)) begin
      tlp   = tlp_item.tlp;

      error_status  = SENT_TLP; 

      cg_tlp_transitions.sample();
    end
  endfunction



  // -------------- Helper Function: to determine error status -------------
  function pcie_dllp_error_e determine_error_status(pcie_dll_dllp_seq_item dllp_item);

      bit [31:0] full_data = {dllp_item.dllp_type, dllp_item.dllp_payload};

    `uvm_info("COVERAGE", $sformatf("-------------------- the whole DLLP: %h --------------------", dllp_item.dllp), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("---------------- DLLP type: %s & state: %s ------------------", dllp_item.dllp_type.name(), state.name()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("---------------- verify CRC result: %b & expected CRC: %h ----------------", dllp_item.verify_crc(), dllp_item.crc), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("-------------------------- VC: %b -------------------------------", dllp_item.dllp_type[2:0]), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("---------------------- hdr_fc: %h & data_fc: %h -------------------", dllp_item.dllp_payload[21:14], dllp_item.dllp_payload[11:0]), UVM_LOW)
    
    // wrong CRC
    if (!(dllp_item.verify_crc())) begin
      return WRONG_CRC;
    end

    // invalid DLLP 
    else if (state == DL_FEATURE_EXCH && dllp_item.dllp_type != DLLP_FEATURE_REQ) begin
      `uvm_info("COVERAGE", $sformatf("Invalid DLLP type %s ", dllp_item.dllp_type.name()), UVM_LOW)
      return INVALID_DLLP;
    end
    else if ((state == DL_INIT_FC1 || state == DL_INIT_FC2) && !(dllp_item.dllp_type inside {DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL, DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL})) begin
      `uvm_info("COVERAGE", $sformatf("Invalid DLLP type %s ", dllp_item.dllp_type.name()), UVM_LOW)
      return INVALID_DLLP;
    end

    // invalid VC (only InitFC DLLPs should be for VC0)
    else if (state inside {DL_INIT_FC1, DL_INIT_FC2} && dllp_item.dllp_type[2:0] != 3'b000) begin
      `uvm_info("COVERAGE", $sformatf("Invalid VC: %b ", dllp_item.dllp_type[2:0]), UVM_LOW)
      return INVALID_VC;
    end

    // errors free
    else begin
      return ERROR_FREE;
    end

  endfunction

endclass : pcie_dll_coverage