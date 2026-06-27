class test_base_delayed_packets extends uvm_test;

  pcie_dll_env_cfg cfg_rc;
  pcie_dll_env_cfg cfg_ep;
  pcie_dll_link_cfg lnk_cfg;
  pcie_dll_env     env_rc;
  pcie_dll_env     env_ep;

  pcie_dll_if_seq if_seq;
  pcie_dll_if_agent if_agent;

  uvm_event target_reached_rc;
  uvm_event target_reached_ep;

   // callbacks instatiation:

  // corrupted crc:
  pcie_dll_tx_drv_cb_crc pcie_dll_tx_drv_cb_crc_env_rc;
  pcie_dll_tx_drv_cb_crc pcie_dll_tx_drv_cb_crc_env_ep;

  // invalid dllp:
  pcie_dll_tx_drv_cb_invalid_dllp pcie_dll_tx_drv_cb_invalid_dllp_env_rc;
  pcie_dll_tx_drv_cb_invalid_dllp pcie_dll_tx_drv_cb_invalid_dllp_env_ep;

  // vc
  pcie_dll_tx_drv_cb_vc pcie_dll_tx_drv_cb_vc_env_rc;
  pcie_dll_tx_drv_cb_vc pcie_dll_tx_drv_cb_vc_env_ep;

  // dllp feature exchange
  //pcie_dll_tx_drv_cb_dl_feature_exch pcie_dll_tx_drv_cb_dl_feature_exch_env_rc;
  //pcie_dll_tx_drv_cb_dl_feature_exch pcie_dll_tx_drv_cb_dl_feature_exch_env_ep;

  `uvm_component_utils(test_base_delayed_packets)

  function new(string name = "test_base_delayed_packets", uvm_component parent = null);
    super.new(name, parent);
    target_reached_rc  = new("target_reached_rc");
    target_reached_ep  = new("target_reached_ep");
  endfunction

  function void build_phase(uvm_phase phase);
    string validation_error_msg;
    int    tb_nbytes;
    pcie_link_width_e tb_link_width;
    pcie_speed_mode_e tb_speed_mode;

    super.build_phase(phase);

     
     
    // Create two separate configs to allow asymmetric link properties (e.g. credits)
    cfg_rc = pcie_dll_env_cfg::type_id::create("cfg_rc");
    cfg_ep = pcie_dll_env_cfg::type_id::create("cfg_ep");
    lnk_cfg = pcie_dll_link_cfg::type_id::create("lnk_cfg");
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
    cfg_rc.init_fc_hdr[FC_P]   = 8'h20;  cfg_rc.init_fc_data[FC_P]   = 12'h100;
    cfg_rc.init_fc_hdr[FC_NP]  = 8'h20;  cfg_rc.init_fc_data[FC_NP]  = 12'h100;
    cfg_rc.init_fc_hdr[FC_CPL] = 8'h20;  cfg_rc.init_fc_data[FC_CPL] = 12'h100;

    cfg_ep.init_fc_hdr[FC_P]   = 8'h40;  cfg_ep.init_fc_data[FC_P]   = 12'h200;
    cfg_ep.init_fc_hdr[FC_NP]  = 8'h40;  cfg_ep.init_fc_data[FC_NP]  = 12'h200;
    cfg_ep.init_fc_hdr[FC_CPL] = 8'h40;  cfg_ep.init_fc_data[FC_CPL] = 12'h200;
    
    // Set the number of transactions to generate for each role (can be overridden from config_db)
    cfg_rc.req_count = 1000;
    cfg_ep.req_count = 1000;

    //for feature exchange test 
    cfg_rc.scaled_fc_supported = 1'b1;
    cfg_ep.scaled_fc_supported = 1'b1;

    if (!cfg_rc.validate(validation_error_msg)) `uvm_fatal("CFG_RC_INV", validation_error_msg)
    if (!cfg_ep.validate(validation_error_msg)) `uvm_fatal("CFG_EP_INV", validation_error_msg)

    // Publish role-specific cfgs to the respective environments
    pcie_dll_env_cfg::set_cfg(this, "env_rc*", cfg_rc);
    pcie_dll_env_cfg::set_cfg(this, "env_ep*", cfg_ep);
    uvm_config_db#(pcie_dll_link_cfg)::set(this, "*", "lnk_cfg", lnk_cfg);
    
    // Set role per-instance
    uvm_config_db#(pcie_dll_role_e)::set(this, "env_rc*", "role", ROLE_RC);
    uvm_config_db#(pcie_dll_role_e)::set(this, "env_ep*", "role", ROLE_EP);

    //events
    uvm_config_db#(uvm_event)::set(this, "env_rc*", "event", target_reached_rc); 
    uvm_config_db#(uvm_event)::set(this, "env_ep*", "event", target_reached_ep);

    env_rc = pcie_dll_env::type_id::create("env_rc", this);
    env_ep = pcie_dll_env::type_id::create("env_ep", this);
    if_agent = pcie_dll_if_agent::type_id::create("if_agent", this);

    `uvm_info("CFG", $sformatf("Applied RC cfg: %s", cfg_rc.summary()), UVM_LOW)
    `uvm_info("CFG", $sformatf("Applied EP cfg: %s", cfg_ep.summary()), UVM_LOW)

    // corrupted crc:
    pcie_dll_tx_drv_cb_crc_env_rc = pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_rc");
    pcie_dll_tx_drv_cb_crc_env_ep = pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_ep");

    // invalid dllp:
    pcie_dll_tx_drv_cb_invalid_dllp_env_rc = pcie_dll_tx_drv_cb_invalid_dllp::type_id::create("pcie_dll_tx_drv_cb_invalid_dllp_env_rc");
    pcie_dll_tx_drv_cb_invalid_dllp_env_ep = pcie_dll_tx_drv_cb_invalid_dllp::type_id::create("pcie_dll_tx_drv_cb_invalid_dllp_env_ep");

    // vc
    pcie_dll_tx_drv_cb_vc_env_rc = pcie_dll_tx_drv_cb_vc::type_id::create("pcie_dll_tx_drv_cb_vc_env_rc");
    pcie_dll_tx_drv_cb_vc_env_ep = pcie_dll_tx_drv_cb_vc::type_id::create("pcie_dll_tx_drv_cb_vc_env_ep");

    // dllp feature exchange
    //pcie_dll_tx_drv_cb_dl_feature_exch_env_rc = pcie_dll_tx_drv_cb_dl_feature_exch::type_id::create("pcie_dll_tx_drv_cb_dl_feature_exch_env_rc");
    //pcie_dll_tx_drv_cb_dl_feature_exch_env_ep = pcie_dll_tx_drv_cb_dl_feature_exch::type_id::create("pcie_dll_tx_drv_cb_dl_feature_exch_env_ep");


   
  endfunction

  function void connect_phase(uvm_phase phase);

    super.connect_phase(phase);

    // inject the callback crc object to the driver
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_ep);

    // inject the callback invalid dllp object to the driver
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_invalid_dllp)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_invalid_dllp_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_invalid_dllp)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_invalid_dllp_env_ep);

    // inject the callback vc object to the driver
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_vc)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_vc_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_vc)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_vc_env_ep);

    // inject the callback feature exchange object to the driver
    // uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch_env_rc);
    // uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_dl_feature_exch_env_ep);


  endfunction
  
  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    

    phase.raise_objection(this, "Waiting for Link Up");
    
    
    `uvm_info("TEST", "Waiting for State Manager to reach ACTIVE...", UVM_LOW)
    
    repeat (2)
    begin
      `uvm_info("TEST", "Starting delayed packets test for both RC and EP", UVM_LOW)
      fork
      begin
        cfg_rc.delayed_packets = 1'b1; // Enable delayed packets for RC
        target_reached_rc.wait_trigger();
        `uvm_info("Target_reached","the RC reached active state!!!!!! ",UVM_LOW)
        #2ns;
      end
      begin 
        cfg_ep.delayed_packets = 1'b1; // Enable delayed packets for EP
        target_reached_ep.wait_trigger(); 
        `uvm_info("Target_reached","the EP reached active state!!!!!!",UVM_LOW)
        #2ns;
      end
    join

      if_seq = pcie_dll_if_seq::type_id::create("if_seq");
      if_seq.start(if_agent.if_sqr);

      #2ns;

    end
    // #100ns;
    
    
    phase.drop_objection(this, "Link is Up. Test Complete.");

  endtask

endclass : test_base_delayed_packets
