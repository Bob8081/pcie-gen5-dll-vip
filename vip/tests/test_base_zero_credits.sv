class test_base_zero_credits extends pcie_dll_test_base;

  pcie_dll_tx_drv_cb_crc         pcie_dll_tx_drv_cb_crc_env_rc;
  pcie_dll_tx_drv_cb_crc         pcie_dll_tx_drv_cb_crc_env_ep;
  pcie_dll_tx_drv_cb_invalid_dllp pcie_dll_tx_drv_cb_invalid_dllp_env_rc;
  pcie_dll_tx_drv_cb_invalid_dllp pcie_dll_tx_drv_cb_invalid_dllp_env_ep;
  pcie_dll_tx_drv_cb_vc          pcie_dll_tx_drv_cb_vc_env_rc;
  pcie_dll_tx_drv_cb_vc          pcie_dll_tx_drv_cb_vc_env_ep;

  pcie_dll_if_seq if_seq;

  `uvm_component_utils(test_base_zero_credits)

  function new(string name = "test_base_zero_credits", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    cfg_rc.init_fc_hdr[FC_P]   = 8'h00;  cfg_rc.init_fc_data[FC_P]   = 12'h000;
    cfg_rc.init_fc_hdr[FC_NP]  = 8'h00;  cfg_rc.init_fc_data[FC_NP]  = 12'h000;
    cfg_rc.init_fc_hdr[FC_CPL] = 8'h00;  cfg_rc.init_fc_data[FC_CPL] = 12'h000;
    cfg_ep.init_fc_hdr[FC_P]   = 8'h00;  cfg_ep.init_fc_data[FC_P]   = 12'h000;
    cfg_ep.init_fc_hdr[FC_NP]  = 8'h00;  cfg_ep.init_fc_data[FC_NP]  = 12'h000;
    cfg_ep.init_fc_hdr[FC_CPL] = 8'h00;  cfg_ep.init_fc_data[FC_CPL] = 12'h000;

    cfg_rc.req_count           = 1000;
    cfg_ep.req_count           = 1000;
    cfg_rc.scaled_fc_supported = 1'b1;
    cfg_ep.scaled_fc_supported = 1'b1;

    pcie_dll_tx_drv_cb_crc_env_rc          = pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_rc");
    pcie_dll_tx_drv_cb_crc_env_ep          = pcie_dll_tx_drv_cb_crc::type_id::create("pcie_dll_tx_drv_cb_crc_env_ep");
    pcie_dll_tx_drv_cb_invalid_dllp_env_rc = pcie_dll_tx_drv_cb_invalid_dllp::type_id::create("pcie_dll_tx_drv_cb_invalid_dllp_env_rc");
    pcie_dll_tx_drv_cb_invalid_dllp_env_ep = pcie_dll_tx_drv_cb_invalid_dllp::type_id::create("pcie_dll_tx_drv_cb_invalid_dllp_env_ep");
    pcie_dll_tx_drv_cb_vc_env_rc           = pcie_dll_tx_drv_cb_vc::type_id::create("pcie_dll_tx_drv_cb_vc_env_rc");
    pcie_dll_tx_drv_cb_vc_env_ep           = pcie_dll_tx_drv_cb_vc::type_id::create("pcie_dll_tx_drv_cb_vc_env_ep");
  endfunction

  function void start_of_simulation_phase(uvm_phase phase);
    super.start_of_simulation_phase(phase);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_crc)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_crc_env_ep);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_invalid_dllp)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_invalid_dllp_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_invalid_dllp)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_invalid_dllp_env_ep);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_vc)::add(env_rc.agent.tx_drv, pcie_dll_tx_drv_cb_vc_env_rc);
    uvm_callbacks#(pcie_dll_tx_drv, pcie_dll_tx_drv_cb_vc)::add(env_ep.agent.tx_drv, pcie_dll_tx_drv_cb_vc_env_ep);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this, "Waiting for Link Up");
    `uvm_info("TEST", "Waiting for State Manager to reach ACTIVE...", UVM_LOW)
    repeat (4) begin
      `uvm_info("TEST", "Starting correct test with zero credits for both RC and EP", UVM_LOW)
      fork
        begin target_reached_rc.wait_trigger(); `uvm_info("TEST", "the RC reached active state!!!!!!", UVM_LOW) #2ns; end
        begin target_reached_ep.wait_trigger(); `uvm_info("TEST", "the EP reached active state!!!!!!", UVM_LOW) #2ns; end
      join
      if_seq = pcie_dll_if_seq::type_id::create("if_seq");
      if_seq.start(if_agent.if_sqr);
      #2ns;
    end
    phase.drop_objection(this, "Link is Up. Test Complete.");
  endtask

endclass : test_base_zero_credits
