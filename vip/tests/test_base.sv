class pcie_dll_test_base extends uvm_test;

  pcie_dll_env_cfg  cfg_rc;
  pcie_dll_env_cfg  cfg_ep;
  pcie_dll_link_cfg lnk_cfg;
  pcie_dll_env      env_rc;
  pcie_dll_env      env_ep;
  pcie_dll_if_agent if_agent;



  `uvm_component_utils(pcie_dll_test_base)

  function new(string name = "pcie_dll_test_base", uvm_component parent = null);
    super.new(name, parent);

  endfunction

  // -------------------------------------------------------------------------
  // build_phase — wire up configs, roles, and environments.
  // Derived tests should call super.build_phase() then override cfg fields.
  // -------------------------------------------------------------------------
  function void build_phase(uvm_phase phase);
    string            validation_error_msg;
    int               tb_nbytes;
    pcie_link_width_e tb_link_width;
    pcie_speed_mode_e tb_speed_mode;

    super.build_phase(phase);

    // Create configs
    cfg_rc  = pcie_dll_env_cfg::type_id::create("cfg_rc");
    cfg_ep  = pcie_dll_env_cfg::type_id::create("cfg_ep");
    lnk_cfg = pcie_dll_link_cfg::type_id::create("lnk_cfg");
    cfg_rc.set_defaults();
    cfg_ep.set_defaults();

    // Pull optional TB-level overrides from config_db
    if (uvm_config_db#(int)::get(this, "", "tb_nbytes", tb_nbytes)) begin
      cfg_rc.nbytes = tb_nbytes;
      cfg_ep.nbytes = tb_nbytes;
      `uvm_info("CFG", $sformatf("Loaded nbytes=%0d from config_db", tb_nbytes), UVM_LOW)
    end
    if (uvm_config_db#(pcie_link_width_e)::get(this, "", "tb_link_width", tb_link_width)) begin
      cfg_rc.link_width = tb_link_width;
      cfg_ep.link_width = tb_link_width;
      `uvm_info("CFG", $sformatf("Loaded link_width=%0d from config_db", tb_link_width), UVM_LOW)
    end
    if (uvm_config_db#(pcie_speed_mode_e)::get(this, "", "tb_speed_mode", tb_speed_mode)) begin
      cfg_rc.speed_mode = tb_speed_mode;
      cfg_ep.speed_mode = tb_speed_mode;
      `uvm_info("CFG", $sformatf("Loaded speed_mode=%0d from config_db", tb_speed_mode), UVM_LOW)
    end

    // Validate and publish configs
    if (!cfg_rc.validate(validation_error_msg)) `uvm_fatal("CFG", validation_error_msg)
    if (!cfg_ep.validate(validation_error_msg)) `uvm_fatal("CFG", validation_error_msg)

    pcie_dll_env_cfg::set_cfg(this, "env_rc*", cfg_rc);
    pcie_dll_env_cfg::set_cfg(this, "env_ep*", cfg_ep);
    uvm_config_db#(pcie_dll_link_cfg)::set(this, "*", "lnk_cfg", lnk_cfg);

    // Role assignment
    uvm_config_db#(pcie_dll_role_e)::set(this, "env_rc*", "role", ROLE_RC);
    uvm_config_db#(pcie_dll_role_e)::set(this, "env_ep*", "role", ROLE_EP);

    // assign values of abnormal behavior weights
    cfg_rc.corrupted_initfc_weight = 40;
    cfg_ep.corrupted_initfc_weight = 40;
    cfg_rc.max_weight              = 100;
    cfg_ep.max_weight              = 100;
    cfg_rc.crc_error_weight        = 2;
    cfg_ep.crc_error_weight        = 2;
    cfg_rc.invalid_dllp_weight     = 2;
    cfg_ep.invalid_dllp_weight     = 2;
    cfg_rc.invalid_VC_weight       = 3;
    cfg_ep.invalid_VC_weight       = 3;



    // Instantiate environments and IF agent
    env_rc   = pcie_dll_env::type_id::create("env_rc",   this);
    env_ep   = pcie_dll_env::type_id::create("env_ep",   this);
    if_agent = pcie_dll_if_agent::type_id::create("if_agent", this);

    `uvm_info("CFG", $sformatf("Applied RC cfg: %s", cfg_rc.summary()), UVM_LOW)
    `uvm_info("CFG", $sformatf("Applied EP cfg: %s", cfg_ep.summary()), UVM_LOW)

  endfunction

  // -------------------------------------------------------------------------
  // start_of_simulation_phase — global verbosity / reporting filters.
  // Override in a derived test to add test-specific filters on top.
  // -------------------------------------------------------------------------
  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);

    // Silence all fatals
    this.set_report_severity_action_hier(UVM_FATAL, UVM_DISPLAY);

    // Silence internal component messages but protocol-level IDs surface.
    // uvm_top.set_report_id_action("TX_MON",        UVM_NO_ACTION);
    // uvm_top.set_report_id_action("RX_MON",        UVM_NO_ACTION);
    // uvm_top.set_report_id_action("INACTIVE_STATE", UVM_NO_ACTION);
    // uvm_top.set_report_id_action("ACTIVE_STATE",  UVM_NO_ACTION);
    // uvm_top.set_report_id_action("AGENT",         UVM_NO_ACTION);
    // uvm_top.set_report_id_action("DRV",           UVM_NO_ACTION);

  endfunction

  // -------------------------------------------------------------------------
  // run_phase — empty; each derived test implements its own scenario.
  // -------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
    super.run_phase(phase);
  endtask

endclass : pcie_dll_test_base
