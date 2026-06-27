class pcie_dll_env_cfg extends uvm_object;
  //TODO : add more feature support details in config

  // Link configuration (hardware-fixed at compile time, set from tb_top)
  pcie_link_width_e link_width;
  pcie_speed_mode_e speed_mode;
  int unsigned      nbytes;

  // Feature enables
  rand bit               enable_replay; // Ack Nack
  rand bit               enable_flow_control; // Flow control DLLPs
  rand bit               enable_pwr_mgmt; // Power management DLLPs
  rand bit               enable_lcrc_checking; // Whether to check LCRC in received TLPs

  // error enable --> generate items may contain errors
       bit               enable_errors;    // 0: error free item, 1: items may contain errors based on determined rate
       bit               corrupted_initfc; // 0: normal behavior for INITFC state, 1: corrupted INITFC state (normal, reopeated and disorder packets)

  // number of items iterations in sequences
  rand int unsigned      req_count;

  //TODO : add the possibilty to simulate the DLLSM for any VC  
  // and not just the default VC0 and maybe add a test that
  // simulates the DLLSM for all the VCs in a random order
  bit [3:0] Current_VC;

  // Data Link Feature Settings
  rand bit               scaled_fc_supported;

  // Initial Flow Control Credits (Associative arrays indexed by pcie_fc_type_e)
  rand bit [1:0]         init_fc_hdr_scale[pcie_fc_type_e]; // 2-bit scale factor for header credits (0=1x, 1=2x, 2=4x, 3=8x)
  rand bit [7:0]         init_fc_hdr[pcie_fc_type_e]; // Initial header credits
  rand bit [1:0]         init_fc_data_scale[pcie_fc_type_e]; // 2-bit scale factor for data credits
  rand bit [11:0]        init_fc_data[pcie_fc_type_e]; // Initial data credits (scaled by init_fc_data_scale)

  // Timing and behavior knobs
  
  // Number of lclk cycles representing the 34 µs Init RX / Feature RX interval
  // (PCIe Base Spec Rev 5.0). At 1 GHz, 34 µs = 34_000 cycles.
  int unsigned           init_rx_interval_cycles;


  // Reporting and coverage controls
  rand bit               enable_coverage;
  rand bit               verbose_scoreboard;
  rand uvm_verbosity     log_level;

  // Common constraints for randomized cfg objects.
  constraint legal_ranges_c {
    nbytes inside {4, 8, 16, 32, 64};
  }

  constraint link_width_geometry_c {
    if (link_width == PCIE_LINK_X1)  nbytes == 4;
    if (link_width == PCIE_LINK_X2)  nbytes == 8;
    if (link_width == PCIE_LINK_X4)  nbytes == 16;
    if (link_width == PCIE_LINK_X8)  nbytes == 32;
    if (link_width == PCIE_LINK_X16) nbytes == 64;
  }

  `uvm_object_utils_begin(pcie_dll_env_cfg)
    `uvm_field_enum(pcie_link_width_e, link_width, UVM_DEFAULT)
    `uvm_field_enum(pcie_speed_mode_e, speed_mode, UVM_DEFAULT)
    `uvm_field_int(nbytes, UVM_DEFAULT)
    `uvm_field_int(enable_replay, UVM_DEFAULT)
    `uvm_field_int(enable_flow_control, UVM_DEFAULT)
    `uvm_field_int(enable_pwr_mgmt, UVM_DEFAULT)
    `uvm_field_int(enable_lcrc_checking, UVM_DEFAULT)
    `uvm_field_int(scaled_fc_supported, UVM_DEFAULT)
    `uvm_field_int(init_rx_interval_cycles, UVM_DEFAULT)
    `uvm_field_int(enable_errors, UVM_DEFAULT)
    `uvm_field_int(corrupted_initfc, UVM_DEFAULT)
    `uvm_field_int(req_count, UVM_DEFAULT)  
    // `uvm_field_aa_int_enumkey(init_fc_hdr_scale, pcie_fc_type_e, UVM_DEFAULT)
    // `uvm_field_aa_int_enumkey(init_fc_hdr, pcie_fc_type_e, UVM_DEFAULT)
    // `uvm_field_aa_int_enumkey(init_fc_data_scale, pcie_fc_type_e, UVM_DEFAULT)
    // `uvm_field_aa_int_enumkey(init_fc_data, pcie_fc_type_e, UVM_DEFAULT)
    `uvm_field_enum(uvm_verbosity, log_level, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "pcie_dll_env_cfg");
    super.new(name);
    set_defaults();
  endfunction

  function void set_defaults();
    link_width            = PCIE_LINK_X16;
    speed_mode            = PCIE_GEN5;
    nbytes                = 64;

    enable_replay         = 1'b1;
    enable_flow_control   = 1'b1;
    enable_pwr_mgmt       = 1'b0;
    enable_lcrc_checking  = 1'b1;

    scaled_fc_supported = 1'b0;

    init_fc_hdr_scale[FC_P]    = 2'b00;
    init_fc_hdr[FC_P]          = 8'h20;
    init_fc_data_scale[FC_P]   = 2'b00;
    init_fc_data[FC_P]         = 12'h100;

    init_fc_hdr_scale[FC_NP]   = 2'b00;
    init_fc_hdr[FC_NP]         = 8'h20;
    init_fc_data_scale[FC_NP]  = 2'b00;
    init_fc_data[FC_NP]        = 12'h100;

    init_fc_hdr_scale[FC_CPL]  = 2'b00;
    init_fc_hdr[FC_CPL]        = 8'h20;
    init_fc_data_scale[FC_CPL] = 2'b00;
    init_fc_data[FC_CPL]       = 12'h100;

    init_rx_interval_cycles = 34_000; // 34 µs @ 1 GHz lclk

    enable_coverage       = 1'b1;
    verbose_scoreboard    = 1'b0;
    log_level             = UVM_MEDIUM;
  endfunction

  function bit validate(ref string validation_error_msg);
    validation_error_msg = "";

    if (!(nbytes inside {4, 8, 16, 32, 64})) begin
      validation_error_msg = "nbytes must be one of {4,8,16,32,64}";
      return 0;
    end


    if (link_width == PCIE_LINK_X16 && nbytes != 64) begin
      validation_error_msg = "link_width PCIE_LINK_X16 requires nbytes=64";
      return 0;
    end

    return 1;
  endfunction

  // Central helper to publish cfg through hierarchy using uvm_config_db.
  static function void set_cfg(
      uvm_component    cntxt,
      string           inst_name,
      pcie_dll_env_cfg cfg,
      string           field_name = "cfg"
    );
    uvm_config_db#(pcie_dll_env_cfg)::set(cntxt, inst_name, field_name, cfg);
  endfunction

  // Central helper to retrieve cfg. returns 0 on miss and optionally reports.
  static function bit get_cfg(
      uvm_component       cntxt,
      string              inst_name,
      ref pcie_dll_env_cfg cfg,
      input string              field_name = "cfg",
      input bit                 required = 1
    );
    bit ok;

    ok = uvm_config_db#(pcie_dll_env_cfg)::get(cntxt, inst_name, field_name, cfg);
    if (!ok && required) begin
      `uvm_error("CFG_MISSING",
        $sformatf("Missing %s for %s", field_name, cntxt.get_full_name()))
    end

    return ok;
  endfunction

  function string summary();
    return $sformatf(
      "link=%0d speed=Gen%0d nbytes=%0d replay=%0b fc=%0b lcrc=%0b sfc=%0b",
      link_width, speed_mode, nbytes,
      enable_replay, enable_flow_control, enable_lcrc_checking,
      scaled_fc_supported
    );
  endfunction

endclass : pcie_dll_env_cfg
