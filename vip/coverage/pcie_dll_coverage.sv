// ---- pcie_dll_coverage ----

class pcie_dll_coverage extends uvm_subscriber #(pcie_dll_base_seq_item);

  // ---- UVM Factory Registration ----
  `uvm_component_utils(pcie_dll_coverage)

  // ---- Signals ----
  bit [47:0]            dllp;           
  bit [127:0]           tlp;
  bit [23:0]            dllp_payload;
  bit [15:0]            crc;            

  pcie_dlcmsm_state_e   state;
  pcie_dlcmsm_state_e   prev_state;

  pcie_dllp_type_e      dllp_type;
  pcie_dllp_error_e     error_status;

  pcie_dll_partner_cfg  dyn_cfg;
  pcie_dll_my_cfg       my_cfg;


  // ---- role of the side ----
   pcie_dll_role_e role;

   pcie_dll_fc_watchdog_status_e  watchdog_status;
   pcie_dll_fc_active_status_e    active_status;

  // events to hit 34 microsecond timeout scenarios in coverage class
  uvm_event timeout_event_fc1;
  uvm_event timeout_event_fc2;
  uvm_event timeout_event_feature;

  // events to hit symmetric/asymmetric active scenarios in coverage class
  uvm_event symmetric_active_event;
  uvm_event asymmetric_active_event;

  // path type signal for controlling
  string path_type;


  // ---- Covergroups ----

    // ---- 1. state machine behavior Coverage Group ----
  covergroup tx_machine_transitions (string path_label);

    option.per_instance = 1;
    option.weight       = 10;  // 10x weight compared to TLP coverage
    option.name         = path_label;
    option.comment      = " Tracks DL state machine transitions";

    cp_state_machine: coverpoint state {
      bins state_machine_normal_flow [] = (DL_INACTIVE => DL_FEATURE_EXCH),
                                          (DL_INACTIVE => DL_INIT_FC1    ),  
                                          (DL_INIT_FC1 => DL_INIT_FC2    ), 
                                          (DL_INIT_FC2 => DL_ACTIVE      );
       
      bins state_machine_drop_link [] = (DL_FEATURE_EXCH => DL_INACTIVE),
                                        (DL_INIT_FC1     => DL_INACTIVE),  
                                        (DL_INIT_FC2     => DL_INACTIVE);
      }
  endgroup

  // ---- 2. DLLP Coverage Group ----
  covergroup cg_dllp_transitions (string path_label);

    option.per_instance = 1;
    option.weight       = 10;  // 10x weight compared to TLP coverage
    option.name         = path_label;
    option.comment      = " Detailed DLLP Analysis — state, type, errors, credits ";


    cp_state: coverpoint state {
      option.comment = " Tracks DL state machine states";
      bins main_states        [] = {DL_FEATURE_EXCH, DL_INIT_FC1, DL_INIT_FC2}; // to be used in crosses 
      //bins start_finish_states[] = {DL_INACTIVE, DL_ACTIVE}; // to trace start and end of sequences    
    }

    cp_dllp_type: coverpoint dllp_type {
      option.comment = " Covers specific PCIe DLLP packet types";
      bins feature_state   = {DLLP_FEATURE_REQ};
      bins init_state_1 [] = {DLLP_INITFC1_P, DLLP_INITFC1_NP, DLLP_INITFC1_CPL}; 
      bins init_state_2 [] = {DLLP_INITFC2_P, DLLP_INITFC2_NP, DLLP_INITFC2_CPL};
    }


    // -- Errors --
    cp_error_status: coverpoint error_status {
      option.comment = " cover different error injection and protocol violations";
      //bins sent_tlp        = {SENT_TLP};
      bins invalid_dllp    = {INVALID_DLLP};
      bins wrong_crc       = {WRONG_CRC};
      bins invalid_vc      = {INVALID_VC};
      bins error_free      = {ERROR_FREE};
      
    }


    cr_inv_dllp: cross cp_state, cp_error_status {
      option.comment = " Invalid DLLP scenarios during states";
      ignore_bins not_invalid_dllp = !binsof(cp_error_status.invalid_dllp); //|| !binsof (cp_state.main_states);
    }

    cr_wrong_crc: cross cp_state, cp_error_status {
      option.comment = " Wrong CRC scenarios during states";
      ignore_bins not_wrong_crc = !binsof(cp_error_status.wrong_crc); //|| !binsof (cp_state.main_states);
    }

    cr_invalid_vc: cross cp_state, cp_error_status {
      option.comment = " Invalid VC scenarios during states";
      ignore_bins not_invalid_vc     = !binsof(cp_error_status.invalid_vc);
      ignore_bins feature_exch       =  binsof(cp_state.main_states) intersect {DL_FEATURE_EXCH};
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

      bins initfc2_witin_initfc1 = (DLLP_INITFC1_P  => DLLP_INITFC2_P),
                                   (DLLP_INITFC1_NP  => DLLP_INITFC2_P);

      bins initfc1_witin_initfc2 = (DLLP_INITFC2_P   => DLLP_INITFC1_NP),
                                   (DLLP_INITFC2_P   => DLLP_INITFC1_P),
                                   (DLLP_INITFC2_NP  => DLLP_INITFC1_P),
                                   (DLLP_INITFC2_NP  => DLLP_INITFC1_NP),
                                   (DLLP_INITFC2_CPL => DLLP_INITFC1_P),
                                   (DLLP_INITFC2_CPL => DLLP_INITFC1_NP);                                      
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
      ignore_bins zero_credit   = !binsof(cp_dllp_type.init_state_1) && !binsof(cp_dllp_type.init_state_2);
    }

    cr_zero_hdr_credits: cross cp_dllp_type, cp_hdr_credits { 
      option.comment = " Checks zero header credit advertisement during Init states";
      ignore_bins zero_credit   = !binsof(cp_dllp_type.init_state_1) && !binsof(cp_dllp_type.init_state_2);
    }
    

  endgroup

  // ---- 2. watchdog Coverage Group ----
  // note: this coverage group is only instantiated for the RX path
  covergroup cg_watchdog (string path_label);

    option.per_instance = 1;
    option.name         = path_label;
    option.weight       = 10;  // high weight the same as DLLP coverage
    option.comment      = " Tracks timeout scenarios for InitFC1 and InitFC2 received packets ";

    cp_watchdog_status: coverpoint watchdog_status {
      bins timeout_feature = {timeout_feature};
      bins timeout_fc1     = {timeout_fc1};
      bins timeout_fc2     = {timeout_fc2};
    }

  endgroup

  // ---- 4. active status Coverage Group ----
  // note: this coverage group is only instantiated for the Tx path
  covergroup cg_active_status (string path_label);

    option.per_instance = 1;
    option.name         = path_label;
    option.weight       = 10;  // high weight the same as DLLP coverage
    option.comment      = " Tracks timeout scenarios for InitFC1 and InitFC2 received packets ";

    cp_active_status: coverpoint active_status {
      bins symmetric_active  = {symmetric_active};
      bins asymmetric_active = {asymmetric_active};
    }

  endgroup

   //  ---- 5. TLP Coverage Group ----
  covergroup cg_tlp_transitions (string path_label);

    option.per_instance = 1;
    option.name         = path_label;
    option.weight       = 1;  // baseline weight for TLP coverage
    option.comment      = " Tracks TLP transmission during DL states ";

    cp_tlp: coverpoint tlp {
      bins send_tlp = {128'hDEADBEEF_CAFEBABE_11223344_55667788};
    }

  endgroup

  // ---- Constructor ----
  function new(string name = "pcie_dll_coverage", uvm_component parent = null);
    super.new(name, parent);

    if (!uvm_config_db#(string)::get(this, "", "path_type", path_type)) begin
      `uvm_fatal("NOCFG", $sformatf("path_type is not set in config_db for coverage instance: %s", name))
    end

    // create coverage groups
    if (path_type == "Tx_path") begin
      cg_dllp_transitions    = new({get_full_name(), "_dllp"});
      cg_tlp_transitions     = new({get_full_name(), "_tlp"});
      tx_machine_transitions = new({get_full_name(), "_tx_machine"});
      cg_active_status       = new({get_full_name(), "_active_status"});

    end
    else begin
      cg_dllp_transitions = new({get_full_name(), "_dllp"});
      cg_tlp_transitions  = new({get_full_name(), "_tlp"});
      cg_watchdog         = new({get_full_name(), "_watchdog"});
    end

  endfunction

  function void build_phase(uvm_phase phase);

    string event_name_fc1 ;
    string event_name_fc2 ;
    string event_name_feature ;

    string event_name_sym ;
    string event_name_asym ;

    super.build_phase(phase);

    // get role from config_db
    if (!uvm_config_db#(pcie_dll_role_e)::get(this, "", "role", role))
      `uvm_fatal("NOCFG", "pcie_dll_env: no role found in config_db")

    if(!uvm_config_db#(pcie_dll_my_cfg)::get(this, "", "my_cfg", my_cfg)) begin
      `uvm_fatal("NOCFG", $sformatf("no my_cfg found in the config_db for %s scoreboard", role.name()))
    end

      // events to hit 34 microsecond timeout scenarios for received packets in coverage class
      event_name_fc1     = $sformatf("timeout_event_fc1_%s", role.name());
      event_name_fc2     = $sformatf("timeout_event_fc2_%s", role.name());
      event_name_feature = $sformatf("timeout_event_feature_%s", role.name());

      timeout_event_fc1     = uvm_event_pool::get_global(event_name_fc1);
      timeout_event_fc2     = uvm_event_pool::get_global(event_name_fc2);
      timeout_event_feature = uvm_event_pool::get_global(event_name_feature);

      // events to hit symmetric/asymmetric active scenarios in coverage class
      event_name_sym          = $sformatf("symmetric_active_event_%s", role.name());
      event_name_asym         = $sformatf("asymmetric_active_event_%s", role.name());

      symmetric_active_event  = uvm_event_pool::get_global(event_name_sym);
      asymmetric_active_event = uvm_event_pool::get_global(event_name_asym);

  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);

    // to be able to read inactive state every loop in the test
    fork 
      forever begin
        wait (my_cfg.dlsm_state != prev_state) begin
          prev_state = state;
          state      = my_cfg.dlsm_state;
          tx_machine_transitions.sample();
          cg_dllp_transitions.sample();
        end
      end
    join_none

      // check timeout scenarios
      if (path_type == "Rx_path") begin
      fork

        begin
          forever begin
            timeout_event_feature.wait_trigger();
            watchdog_status = timeout_feature;
            cg_watchdog.sample();
            watchdog_status = no_timeout;
          end
        end

        begin
          forever begin
            timeout_event_fc1.wait_trigger();
            watchdog_status = timeout_fc1;
            cg_watchdog.sample();
            watchdog_status = no_timeout;
          end
        end

        begin
          forever begin
            timeout_event_fc2.wait_trigger();
            watchdog_status = timeout_fc2;
            cg_watchdog.sample();
            watchdog_status = no_timeout;
          end
        end
        
      join_none
  end

      // check active status scenarios
      if (path_type == "Tx_path") begin
        fork

        begin
          forever begin
            symmetric_active_event.wait_trigger();
            active_status  = symmetric_active;
            cg_active_status.sample();
            active_status  = not_active;
          end
        end

        begin
          forever begin
            asymmetric_active_event.wait_trigger();
            active_status  = asymmetric_active;
            cg_active_status.sample();
            active_status  = not_active;
          end
        end
        
      join_none

    end

    

  endtask


  // ---- Write for sequence item ----
  virtual function void write(pcie_dll_base_seq_item t);
    pcie_dll_dllp_seq_item dllp_item;
    pcie_dll_tlp_seq_item  tlp_item;

    //state         = my_cfg.dlsm_state; // Tx path state for both Rx and Tx paths
    if (path_type == "Tx_path") begin
        error_status  = pcie_dll_pkg::error_expector::tx_determine_error_status(t, state);
        tx_machine_transitions.sample();
      end
      else begin
        error_status  = pcie_dll_pkg::error_expector::rx_determine_error_status(t, state);
      end


    if ($cast(dllp_item, t)) begin
      dllp          = dllp_item.dllp;
      dllp_type     = dllp_item.dllp_type;
      dllp_payload  = dllp_item.dllp_payload;
      crc           = dllp_item.crc;
      
      cg_dllp_transitions.sample();

      `uvm_info("COVERAGE", $sformatf("------------------------- coverage ----------------------------"), UVM_LOW)
      `uvm_info("COVERAGE", $sformatf("--------------------- %s in %s ------------------", path_type, role.name()), UVM_LOW)
      `uvm_info("COVERAGE", $sformatf("----------- DLLP: %h  in Tx_state: %s ----------", dllp, state), UVM_LOW)
      `uvm_info("COVERAGE", $sformatf("-------DLLP type: %s, error status: %s -------", dllp_type.name(), error_status.name()), UVM_LOW)

    end
    else if ($cast(tlp_item, t)) begin
      tlp   = tlp_item.tlp;

      `uvm_info("COVERAGE", $sformatf("------------------------- coverage ----------------------------"), UVM_LOW)
      `uvm_info("COVERAGE", $sformatf("-------------------- %s in %s ------------------", path_type, role.name()), UVM_LOW)
      `uvm_info("COVERAGE", $sformatf("----------- TLP: %h  in Tx_state: %s ----------", tlp, state), UVM_LOW)

      cg_tlp_transitions.sample();
    end

  endfunction

endclass : pcie_dll_coverage