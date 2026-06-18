class pcie_dll_env extends uvm_env;

  pcie_dll_env_cfg cfg;
  pcie_dll_partner_cfg partner_cfg;
  pcie_dll_my_cfg my_cfg;
  pcie_dll_role_e  role;
  pcie_dll_agent   agent;
  pcie_dll_scoreboard scoreboard;
  pcie_dll_fc_watchdog fc_watchdog;


  `uvm_component_utils(pcie_dll_env)

  function new(string name = "pcie_dll_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
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
    //TODO:add the coverage collector here in the next stage

  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Scoreboard connections
    agent.state_ap.connect(scoreboard.state_export);
    agent.rx_mon.mon_rx_ap.connect(scoreboard.rx_export);
    agent.tx_mon.mon_tx_ap.connect(scoreboard.tx_export);
    // Watchdog connections
    agent.state_ap.connect(fc_watchdog.state_export);
    agent.rx_mon.mon_rx_ap.connect(fc_watchdog.rx_export);
  endfunction

endclass : pcie_dll_env
