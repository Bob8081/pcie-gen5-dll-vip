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

  // Data Link Feature Settings
  rand bit               scaled_fc_supported;

  // Initial Flow Control Credits
  rand bit [1:0]         init_fc_hdr_scale_p;
  rand bit [7:0]         init_fc_hdr_p;
  rand bit [1:0]         init_fc_data_scale_p;
  rand bit [11:0]        init_fc_data_p;

  rand bit [1:0]         init_fc_hdr_scale_np;
  rand bit [7:0]         init_fc_hdr_np;
  rand bit [1:0]         init_fc_data_scale_np;
  rand bit [11:0]        init_fc_data_np;

  rand bit [1:0]         init_fc_hdr_scale_cpl;
  rand bit [7:0]         init_fc_hdr_cpl;
  rand bit [1:0]         init_fc_data_scale_cpl;
  rand bit [11:0]        init_fc_data_cpl;

  // Timing and behavior knobs
  rand int unsigned      ack_max_latency;
  rand int unsigned      replay_timer_cycles;
  rand int unsigned      in_flight_replay_depth;
  rand int unsigned      num_tlp_per_sequence;
  rand int unsigned      dllp_latency;


  // Reporting and coverage controls
  rand bit               enable_coverage;
  rand bit               verbose_scoreboard;
  rand uvm_verbosity     log_level;

  // Common constraints for randomized cfg objects.
  constraint legal_ranges_c {
    nbytes inside {4, 8, 16, 32, 64};
    ack_max_latency inside {[1:1024]};
    replay_timer_cycles inside {[4:65535]};
    in_flight_replay_depth inside {[1:4096]};
    num_tlp_per_sequence inside {[1:1000000]};
    dllp_latency inside {[0:1024]};
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
    `uvm_field_int(init_fc_hdr_scale_p, UVM_DEFAULT)
    `uvm_field_int(init_fc_hdr_p, UVM_DEFAULT)
    `uvm_field_int(init_fc_data_scale_p, UVM_DEFAULT)
    `uvm_field_int(init_fc_data_p, UVM_DEFAULT)
    `uvm_field_int(init_fc_hdr_scale_np, UVM_DEFAULT)
    `uvm_field_int(init_fc_hdr_np, UVM_DEFAULT)
    `uvm_field_int(init_fc_data_scale_np, UVM_DEFAULT)
    `uvm_field_int(init_fc_data_np, UVM_DEFAULT)
    `uvm_field_int(init_fc_hdr_scale_cpl, UVM_DEFAULT)
    `uvm_field_int(init_fc_hdr_cpl, UVM_DEFAULT)
    `uvm_field_int(init_fc_data_scale_cpl, UVM_DEFAULT)
    `uvm_field_int(init_fc_data_cpl, UVM_DEFAULT)
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

    init_fc_hdr_scale_p    = 2'b00;
    init_fc_hdr_p          = 8'h20;
    init_fc_data_scale_p   = 2'b00;
    init_fc_data_p         = 12'h100;

    init_fc_hdr_scale_np   = 2'b00;
    init_fc_hdr_np         = 8'h20;
    init_fc_data_scale_np  = 2'b00;
    init_fc_data_np        = 12'h100;

    init_fc_hdr_scale_cpl  = 2'b00;
    init_fc_hdr_cpl        = 8'h20;
    init_fc_data_scale_cpl = 2'b00;
    init_fc_data_cpl       = 12'h100;

    ack_max_latency       = 16;
    replay_timer_cycles   = 256;
    in_flight_replay_depth = 64;
    num_tlp_per_sequence  = 32;
    dllp_latency          = 4;

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

    if (!(ack_max_latency inside {[1:1024]})) begin
      validation_error_msg = "ack_max_latency must be in [1..1024]";
      return 0;
    end

    if (!(replay_timer_cycles inside {[4:65535]})) begin
      validation_error_msg = "replay_timer_cycles must be in [4..65535]";
      return 0;
    end

    if (!(in_flight_replay_depth inside {[1:4096]})) begin
      validation_error_msg = "in_flight_replay_depth must be in [1..4096]";
      return 0;
    end

    if (!(num_tlp_per_sequence inside {[1:1000000]})) begin
      validation_error_msg = "num_tlp_per_sequence must be in [1..1000000]";
      return 0;
    end

    if (!(dllp_latency inside {[0:1024]})) begin
      validation_error_msg = "dllp_latency must be in [0..1024]";
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
      "link=%0d speed=Gen%0d nbytes=%0d replay=%0b fc=%0b lcrc=%0b sfc=%0b ack_max=%0d replay_tmr=%0d depth=%0d",
      link_width, speed_mode, nbytes,
      enable_replay, enable_flow_control, enable_lcrc_checking,
      scaled_fc_supported,
      ack_max_latency, replay_timer_cycles, in_flight_replay_depth
    );
  endfunction

endclass : pcie_dll_env_cfg
