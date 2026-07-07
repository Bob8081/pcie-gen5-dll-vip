class pcie_dll_agent extends uvm_component;


  pcie_dll_env_cfg cfg;
  pcie_dll_role_e  role;

  pcie_dll_state_mgr state_mgr;
  pcie_dll_tx_mon tx_mon;
  pcie_dll_rx_mon rx_mon;
  pcie_dll_seqr sqr;
  pcie_dll_tx_drv tx_drv;

  uvm_analysis_port #(pcie_dlcmsm_state_e)        state_ap;
  uvm_analysis_port #(pcie_dll_base_seq_item)     agent_tx_ap;
  uvm_analysis_port #(pcie_dll_base_seq_item)     agent_rx_ap;
  uvm_analysis_port #(pcie_fc_pkt_counters_s)  agent_counter_ap;

  virtual pcie_lpif_if myvif;

  `uvm_component_utils(pcie_dll_agent)
 
  function new(string name = "pcie_dll_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    state_ap          = new("state_ap", this);
    agent_tx_ap       = new("agent_tx_ap", this);
    agent_rx_ap       = new("agent_rx_ap", this);
    agent_counter_ap  = new("agent_counter_ap", this);

    //get the configuration for the agent
    if (!pcie_dll_env_cfg::get_cfg(this, "", cfg)) begin
      `uvm_fatal("NOCFG",$sformatf("couldn't load the configuration object for this agent %s", get_full_name()))
    end
    
    if (!uvm_config_db#(pcie_dll_role_e)::get(this, "", "role", role)) begin
      `uvm_fatal("NOCFG", "No role configuration found for pcie_dll_agent")
    end

    
    
    //create the components of the agent  
    state_mgr = pcie_dll_state_mgr::type_id::create("state_mgr", this);
    tx_mon = pcie_dll_tx_mon::type_id::create("tx_mon", this);
    rx_mon = pcie_dll_rx_mon::type_id::create("rx_mon", this);
    sqr = pcie_dll_seqr::type_id::create("sqr", this);
    tx_drv = pcie_dll_tx_drv::type_id::create("tx_drv", this);


     //set the role for the components
    tx_drv.role = role;
    tx_mon.role = role;
    rx_mon.role = role;
    state_mgr.role = role;
    state_mgr.cfg = cfg; //pass the configuration to the state manager, which will pass it to the states when needed

    //setting the VIF for the components
    if (role == ROLE_RC) begin
      if(!uvm_config_db#(virtual pcie_lpif_if)::get(this, "", "rc_vif", myvif)) begin
        `uvm_fatal("NOVIF", $sformatf("Virtual interface not set for: %s .",get_full_name()))
      end
      tx_drv.vif = myvif;
      tx_mon.vif = myvif;
      rx_mon.vif = myvif;
    end
    else if (role == ROLE_EP) begin
      if(!uvm_config_db#(virtual pcie_lpif_if)::get(this, "", "ep_vif", myvif)) begin
        `uvm_fatal("NOVIF", $sformatf("Virtual interface not set for: %s .",get_full_name()))
      end
      tx_drv.vif = myvif;
      tx_mon.vif = myvif;
      rx_mon.vif = myvif;
    end
    else begin
      `uvm_fatal("AGENT", "Invalid role specified for pcie_dll_agent. Role must be either ROLE_RC or ROLE_EP.")
    end

    state_mgr.dllp_sequencer = sqr;


  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    rx_mon.mon_rx_ap.connect(state_mgr.dllp_export);
    tx_drv.seq_item_port.connect(sqr.seq_item_export);
    state_mgr.state_ap.connect(state_ap);
    tx_mon.mon_tx_ap.connect(this.agent_tx_ap);
    rx_mon.mon_rx_ap.connect(this.agent_rx_ap);
    state_mgr.fc_pkt_counter_ap.connect(this.agent_counter_ap);
  endfunction

endclass : pcie_dll_agent