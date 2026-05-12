
class pcie_dll_test_base extends uvm_test;

  pcie_dll_env_cfg cfg_rc;
  pcie_dll_env_cfg cfg_ep;
  pcie_dll_env     env_rc;
  pcie_dll_env     env_ep;

  uvm_event target_reached;

  // callbacks instatiation:

  // corrupted crc:
  pcie_dll_tx_drv_cb_crc pcie_dll_tx_drv_cb_crc_env_rc;
  pcie_dll_tx_drv_cb_crc pcie_dll_tx_drv_cb_crc_env_ep;

  // invalid dllp:
  pcie_dll_tx_drv_cb_invalid_dllp pcie_dll_tx_drv_cb_invalid_dllp_env_rc;
  pcie_dll_tx_drv_cb_invalid_dllp pcie_dll_tx_drv_cb_invalid_dllp_env_ep;

  // dllp feature exchange
  pcie_dll_tx_drv_cb_dl_feature_exch pcie_dll_tx_drv_cb_dl_feature_exch_env_rc;
  pcie_dll_tx_drv_cb_dl_feature_exch pcie_dll_tx_drv_cb_dl_feature_exch_env_ep;

  `uvm_component_utils(pcie_dll_test_base)

  function new(string name = "pcie_dll_test_base", uvm_component parent = null);
    super.new(name, parent);
    target_reached  = new("target_reached");
  endfunction

  function void build_phase(uvm_phase phase);
    string validation_error_msg;
    int    tb_nbytes;
    pcie_link_width_e tb_link_width;
    pcie_speed_mode_e tb_speed_mode;
    
    // callback handles

    // corrupted crc:
    pcie_dll_tx_drv_cb_crc_env_rc = pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_rc");
    pcie_dll_tx_drv_cb_crc_env_ep = pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_ep");

    // invalid dllp:
    pcie_dll_tx_drv_cb_invalid_dllp_env_rc = pcie_dll_tx_drv_cb_invalid_dllp::type_id::create("pcie_dll_tx_drv_cb_invalid_dllp_env_rc");
    pcie_dll_tx_drv_cb_invalid_dllp_env_ep = pcie_dll_tx_drv_cb_invalid_dllp::type_id::create("pcie_dll_tx_drv_cb_invalid_dllp_env_ep");

    // dllp feature exchange
    pcie_dll_tx_drv_cb_dl_feature_exch_env_rc = pcie_dll_tx_drv_cb_dl_feature_exch::type_id::create("pcie_dll_tx_drv_cb_dl_feature_exch_env_rc");
    pcie_dll_tx_drv_cb_dl_feature_exch_env_ep = pcie_dll_tx_drv_cb_dl_feature_exch::type_id::create("pcie_dll_tx_drv_cb_dl_feature_exch_env_ep");



    super.build_phase(phase);

     
     uvm_config_db#(uvm_event)::set(this, "*", "event", target_reached);
    // Create two separate configs to allow asymmetric link properties (e.g. credits)
    cfg_rc = pcie_dll_env_cfg::type_id::create("cfg_rc");
    cfg_ep = pcie_dll_env_cfg::type_id::create("cfg_ep");
    cfg_rc.set_defaults();
    cfg_ep.set_defaults();

    // Read testbench-level parameters from config_db and apply to both.
    if (uvm_config_db#(int)::get(this, "", "tb_nbytes", tb_nbytes)) begin
      cfg_rc.nbytes = tb_nbytes; cfg_ep.nbytes = tb_nbytes;
      `uvm_info("CFG", $sformatf("Loaded nbytes=%0d from config_db", tb_nbytes), UVM_LOW)
    end
    if (uvm_config_db#(pcie_link_width_e)::get(this, "", "tb_link_width", tb_link_width)) begin
      cfg_rc.link_width = tb_link_width; cfg_ep.link_width = tb_link_width;
      `uvm_info("CFG", $sformatf("Loaded link_width=%0d from config_db", tb_link_width), UVM_LOW)
    end
    if (uvm_config_db#(pcie_speed_mode_e)::get(this, "", "tb_speed_mode", tb_speed_mode)) begin
      cfg_rc.speed_mode = tb_speed_mode; cfg_ep.speed_mode = tb_speed_mode;
      `uvm_info("CFG", $sformatf("Loaded speed_mode=%0d from config_db", tb_speed_mode), UVM_LOW)
    end

    // Differentiate the initial flow control credits
    cfg_rc.init_fc_hdr_p = 8'h20;  cfg_rc.init_fc_data_p = 12'h100;
    cfg_rc.init_fc_hdr_np = 8'h20; cfg_rc.init_fc_data_np = 12'h100;
    cfg_rc.init_fc_hdr_cpl = 8'h20; cfg_rc.init_fc_data_cpl = 12'h100;

    cfg_ep.init_fc_hdr_p = 8'h40;  cfg_ep.init_fc_data_p = 12'h200;
    cfg_ep.init_fc_hdr_np = 8'h40; cfg_ep.init_fc_data_np = 12'h200;
    cfg_ep.init_fc_hdr_cpl = 8'h40; cfg_ep.init_fc_data_cpl = 12'h200;

    if (!cfg_rc.validate(validation_error_msg)) `uvm_fatal("CFG_RC_INV", validation_error_msg)
    if (!cfg_ep.validate(validation_error_msg)) `uvm_fatal("CFG_EP_INV", validation_error_msg)

    // Publish role-specific cfgs to the respective environments
    pcie_dll_env_cfg::set_cfg(this, "env_rc*", cfg_rc);
    pcie_dll_env_cfg::set_cfg(this, "env_ep*", cfg_ep);

    // Set role per-instance
    uvm_config_db#(pcie_dll_role_e)::set(this, "env_rc*", "role", ROLE_RC);
    uvm_config_db#(pcie_dll_role_e)::set(this, "env_ep*", "role", ROLE_EP);

    env_rc = pcie_dll_env::type_id::create("env_rc", this);
    env_ep = pcie_dll_env::type_id::create("env_ep", this);

    `uvm_info("CFG", $sformatf("Applied RC cfg: %s", cfg_rc.summary()), UVM_LOW)
    `uvm_info("CFG", $sformatf("Applied EP cfg: %s", cfg_ep.summary()), UVM_LOW)

   
  endfunction

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    // inject the callback crc object to the driver
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_ep);

    // inject the callback invalid dllp object to the driver
    // uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_invalid_dllp)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_invalid_dllp_env_rc);
    // uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_invalid_dllp)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_invalid_dllp_env_ep);

    // inject the callback feature exchange object to the driver
    // uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch_env_rc);
    // uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch_env_ep);


  endfunction


  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    

    phase.raise_objection(this, "Waiting for Link Up");
    
    
    `uvm_info("TEST", "Waiting for State Manager to reach ACTIVE...", UVM_LOW)
    target_reached.wait_trigger();
    
    
    // #100ns;
    
    
    phase.drop_objection(this, "Link is Up. Test Complete.");

  endtask

endclass : pcie_dll_test_base
