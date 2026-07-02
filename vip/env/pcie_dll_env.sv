class pcie_dll_env extends uvm_env;

  pcie_dll_env_cfg      cfg;
  pcie_dll_partner_cfg  partner_cfg;
  pcie_dll_my_cfg       my_cfg;
  pcie_dll_role_e       role;
  pcie_dll_agent        agent;
  pcie_dll_scoreboard   scoreboard;
  pcie_dll_fc_watchdog  fc_watchdog;
  pcie_dll_coverage     cov_tx;
  pcie_dll_coverage     cov_rx;


  `uvm_component_utils(pcie_dll_env)

  function new(string name = "pcie_dll_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);

    string tx_cov_inst_name = "cov_tx";
    string rx_cov_inst_name = "cov_rx";

    super.build_phase(phase);


    // Resolve role before creating any sub-components that depend on it
    if (!uvm_config_db#(pcie_dll_role_e)::get(this, "", "role", role))
      `uvm_fatal("NOCFG", "pcie_dll_env: no role found in config_db")

    agent = pcie_dll_agent::type_id::create("agent", this);
    scoreboard = pcie_dll_scoreboard::type_id::create("scoreboard", this);
    fc_watchdog = pcie_dll_fc_watchdog::type_id::create("fc_watchdog", this);
    fc_watchdog.role = role;

    //setting the partner_cfg object for storing link partner data and other time changing values
    partner_cfg = pcie_dll_partner_cfg::type_id::create("partner_cfg");
    uvm_config_db#(pcie_dll_partner_cfg)::set(this, "*", "partner_cfg", partner_cfg);

    my_cfg = pcie_dll_my_cfg::type_id::create("my_cfg");
    uvm_config_db#(pcie_dll_my_cfg)::set(this, "*", "my_cfg", my_cfg);

    uvm_config_db#(string)::set(this, tx_cov_inst_name, "path_type", "Tx_path");
    uvm_config_db#(string)::set(this, rx_cov_inst_name, "path_type", "Rx_path");

    // create coverage collector
    cov_tx = pcie_dll_coverage::type_id::create(tx_cov_inst_name, this);
    cov_rx = pcie_dll_coverage::type_id::create(rx_cov_inst_name, this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // coverage connections
    agent.agent_tx_ap.connect(cov_tx.analysis_export);
    agent.agent_rx_ap.connect(cov_rx.analysis_export);

    // Scoreboard connections
    agent.state_ap.connect(scoreboard.state_export);
    agent.agent_rx_ap.connect(scoreboard.rx_export);
    agent.agent_tx_ap.connect(scoreboard.tx_export);
    agent.agent_counter_ap.connect(scoreboard.counter_export);

    // Watchdog connections
    agent.state_ap.connect(fc_watchdog.state_export);
    agent.agent_rx_ap.connect(fc_watchdog.rx_export);



  endfunction

endclass : pcie_dll_env
