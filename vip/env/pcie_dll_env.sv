class pcie_dll_env extends uvm_env;

  pcie_dll_env_cfg cfg;
  pcie_dll_role_e  role;
  pcie_dll_agent   agent;
  //pcie_dll_scoreboard scoreboard;
  pcie_dll_coverage  cov_tx;
  pcie_dll_coverage  cov_rx;
  pcie_dll_dynamic_cfg dyn_cfg;

  `uvm_component_utils(pcie_dll_env)

  function new(string name = "pcie_dll_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent = pcie_dll_agent::type_id::create("agent", this);
    //scoreboard = pcie_dll_scoreboard::type_id::create("scoreboard", this);
    cov_tx = pcie_dll_coverage::type_id::create("cov_tx", this);
    cov_rx = pcie_dll_coverage::type_id::create("cov_rx", this);

    //create the dynamic cfg object for storing link partner data and other time changing values
    dyn_cfg = pcie_dll_dynamic_cfg::type_id::create("dyn_cfg");
    uvm_config_db#(pcie_dll_dynamic_cfg)::set(this, "*", "dyn_cfg", dyn_cfg);
    //TODO:add the coverage collector here in the next stage

  endfunction 

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    //agent.state_ap.connect(scoreboard.state_export);
    agent.agent_tx_ap.connect(cov_tx.analysis_export);
    agent.agent_rx_ap.connect(cov_rx.analysis_export);
    agent.state_ap.connect(cov_tx.state_export);
    agent.state_ap.connect(cov_rx.state_export);  
  endfunction

endclass : pcie_dll_env
