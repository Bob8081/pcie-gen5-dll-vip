// NOTE: The scoreboard already declares _tx, _rx, _state.  The watchdog needs
// separate suffixes to avoid duplicate macro definitions inside the package.
`uvm_analysis_imp_decl(_wd_rx)
`uvm_analysis_imp_decl(_wd_state)

class pcie_dll_fc_watchdog extends uvm_component;


  // Parameters

  // Configuration handle : interval and other knobs live here
  pcie_dll_env_cfg cfg;


  // State tracking

  pcie_dlcmsm_state_e curr_state;   // current DLCMSM state
  bit                 wdog_active;  // 1 while the watchdog timer is running

  // Per-FC-round reset triggers.
  // The timer is reset when we see the FIRST DLLP of a new round (InitFC1_P or InitFC2_P).
  event fc1_set_started;       // triggered by InitFC1_P while in DL_INIT_FC1
  event fc2_set_started;       // triggered by InitFC2_P while in DL_INIT_FC2
  event feature_dllp_received; // triggered by DLLP_FEATURE_REQ while in DL_FEATURE_EXCH

  // events to hit timeout scenarios in coverage class
  uvm_event timeout_event_fc1;
  uvm_event timeout_event_fc2;
  uvm_event timeout_event_feature;


  // Interface : needed for clock access

  virtual pcie_lpif_if vif;


  // Analysis ports

  uvm_analysis_imp_wd_rx    #(pcie_dll_base_seq_item, pcie_dll_fc_watchdog) rx_export;
  uvm_analysis_imp_wd_state #(pcie_dlcmsm_state_e,    pcie_dll_fc_watchdog) state_export;


  // Role (for diagnostic messages)

  pcie_dll_role_e role;

  `uvm_component_utils(pcie_dll_fc_watchdog)


  function new(string name = "pcie_dll_fc_watchdog", uvm_component parent = null);
    super.new(name, parent);
    curr_state  = DL_INACTIVE;
    wdog_active = 0;
  endfunction


  function void build_phase(uvm_phase phase);

    string event_name_fc1 ;
    string event_name_fc2 ;
    string event_name_feature ;

    super.build_phase(phase);

    rx_export    = new("rx_export",    this);
    state_export = new("state_export", this);

    // Fetch shared environment configuration
    if (!pcie_dll_env_cfg::get_cfg(this, "", cfg))
      `uvm_fatal("NOCFG", "FC watchdog: env cfg not found in config_db")

    // Retrieve the virtual interface for clock edge sampling.
    // The watchdog accepts either the RC or EP VIF : both share the same lclk.
    if (role == ROLE_RC) begin
      if (!uvm_config_db#(virtual pcie_lpif_if)::get(this, "", "rc_vif", vif))
        `uvm_fatal("NOVIF", "FC watchdog (RC): rc_vif not set in config_db")
    end else begin
      if (!uvm_config_db#(virtual pcie_lpif_if)::get(this, "", "ep_vif", vif))
        `uvm_fatal("NOVIF", "FC watchdog (EP): ep_vif not set in config_db")
    end

    `uvm_info("WDOG",
      $sformatf("[%s] FC watchdog built. Interval = %0d cycles (%0d ns)",
        role.name(), cfg.init_rx_interval_cycles, cfg.init_rx_interval_cycles),
      UVM_MEDIUM)

    // events to hit timeout scenarios in coverage class
    event_name_fc1        = $sformatf("timeout_event_fc1_%s", role.name());
    event_name_fc2        = $sformatf("timeout_event_fc2_%s", role.name());
    event_name_feature    = $sformatf("timeout_event_feature_%s", role.name());
    timeout_event_fc1     = uvm_event_pool::get_global(event_name_fc1);
    timeout_event_fc2     = uvm_event_pool::get_global(event_name_fc2);
    timeout_event_feature = uvm_event_pool::get_global(event_name_feature);
  endfunction


  // run_phase: spawn the three independent watchdog threads
  task run_phase(uvm_phase phase);
    fork
      run_feature_watchdog(); // PCIe Spec: Feature RX Interval : 34 µs
      run_fc1_watchdog();     // PCIe Spec: Init TX Interval (FC1) : 34 µs
      run_fc2_watchdog();     // PCIe Spec: Init TX Interval (FC2) : 34 µs
    join_none
  endtask



  // Feature watchdog thread

  // Waits for the state to enter DL_FEATURE_EXCH, then monitors that DLLP_FEATURE_REQ
  // arrives at least every cfg.init_rx_interval_cycles cycles.
  // Exits when the state leaves DL_FEATURE_EXCH.

  task run_feature_watchdog();
    forever begin
      // wait for DL_FEATURE_EXCH entry
      wait (curr_state == DL_FEATURE_EXCH);
      `uvm_info("WDOG",
        $sformatf("[%s] FEAT_ARMED : for DL_FEATURE_EXCH. Interval = %0d cycles",
          role.name(), cfg.init_rx_interval_cycles),
        UVM_MEDIUM)

      // run timer loop while in DL_FEATURE_EXCH
      while (curr_state == DL_FEATURE_EXCH) begin
        fork
          begin : feat_timer_thread
            // Count the full interval; fire ERROR if no feature DLLP arrived
            repeat (cfg.init_rx_interval_cycles) @(posedge vif.lclk);
            if (curr_state == DL_FEATURE_EXCH) begin
              // trigger the coverage event for this timeout scenario
              timeout_event_feature.trigger();

              // Spec violation: DLLP_FEATURE_REQ not received within the interval
              `uvm_error("WDOG",
                $sformatf(
                  "[%s] FEAT_TIMEOUT: DLLP_FEATURE_REQ not received within %0d cycles (%0d us) while in DL_FEATURE_EXCH.",
                  role.name(), cfg.init_rx_interval_cycles,
                  cfg.init_rx_interval_cycles / 1000))
            end
          end : feat_timer_thread

          begin : feat_reset_thread
            // Any DLLP_FEATURE_REQ reception resets the timer
            @feature_dllp_received;
            `uvm_info("WDOG",
              $sformatf("[%s] FEAT_RESET : DLLP_FEATURE_REQ received.", role.name()),
              UVM_HIGH)
          end : feat_reset_thread

          begin : feat_exit_thread
            // Disarm cleanly when leaving DL_FEATURE_EXCH
            wait (curr_state != DL_FEATURE_EXCH);
          end : feat_exit_thread

        join_any
        disable fork;

        if (curr_state != DL_FEATURE_EXCH) break;
      end

      `uvm_info("WDOG",
        $sformatf("[%s] FEAT_DISARMED : left DL_FEATURE_EXCH.", role.name()),
        UVM_MEDIUM)

      wait (curr_state != DL_FEATURE_EXCH);
    end
  endtask


  // FC1 watchdog thread

  // Waits for the state to enter DL_INIT_FC1, then monitors that InitFC1_P
  // arrives at least every cfg.init_tx_interval_cycles cycles.
  // Exits when the state leaves DL_INIT_FC1.
  task run_fc1_watchdog();
    forever begin
      // wait for DL_INIT_FC1 entry
      wait (curr_state == DL_INIT_FC1);
      `uvm_info("WDOG",
        $sformatf("[%s] FC1_ARMED : for DL_INIT_FC1. Interval = %0d cycles",
          role.name(), cfg.init_rx_interval_cycles),
        UVM_MEDIUM)

      wdog_active = 1;

      // run timer loop while in DL_INIT_FC1
      while (curr_state == DL_INIT_FC1) begin
        fork
          begin : timer_thread
            // Count up to the interval; if we reach it -> ERROR
            repeat (cfg.init_rx_interval_cycles) @(posedge vif.lclk);
            if (curr_state == DL_INIT_FC1) begin
              // trigger the coverage event for this timeout scenario
              timeout_event_fc1.trigger();

              // Spec violation: InitFC1_P not received within the interval
              `uvm_error("WDOG",
                $sformatf(
                  "[%s] FC1_TIMEOUT: InitFC1 set (P+NP+Cpl) not started within %0d cycles (%0d us). ",
                  role.name(), cfg.init_rx_interval_cycles,
                  cfg.init_rx_interval_cycles / 1000))
            end
          end : timer_thread

          begin : reset_thread
            // Wait for next InitFC1_P to reset the timer
            @fc1_set_started;
            `uvm_info("WDOG",
              $sformatf("[%s] FC1_RESET : InitFC1_P received.", role.name()),
              UVM_HIGH)
          end : reset_thread

          begin : exit_thread
            // Exit if we leave DL_INIT_FC1
            wait (curr_state != DL_INIT_FC1);
          end : exit_thread

        join_any
        disable fork;

        // If we exited because the state changed, break the while loop
        if (curr_state != DL_INIT_FC1) break;
      end

      wdog_active = 0;
      `uvm_info("WDOG",
        $sformatf("[%s] FC1_DISARMED : left DL_INIT_FC1.", role.name()),
        UVM_MEDIUM)

      // Wait until we are no longer in DL_INIT_FC1 before re-checking
      // (handles the edge case where curr_state flips back immediately)
      wait (curr_state != DL_INIT_FC1);
    end
  endtask


  // FC2 watchdog thread

  // Mirror of run_fc1_watchdog but monitors DL_INIT_FC2 / InitFC2_P.
  task run_fc2_watchdog();
    forever begin
      // wait for DL_INIT_FC2 entry
      wait (curr_state == DL_INIT_FC2);
      `uvm_info("WDOG",
        $sformatf("[%s] FC2_ARMED : for DL_INIT_FC2. Interval = %0d cycles",
          role.name(), cfg.init_rx_interval_cycles),
        UVM_MEDIUM)

      // run timer loop while in DL_INIT_FC2
      while (curr_state == DL_INIT_FC2) begin
        fork
          begin : timer_thread
            repeat (cfg.init_rx_interval_cycles) @(posedge vif.lclk);
            if (curr_state == DL_INIT_FC2) begin
              // trigger the coverage event for this timeout scenario
              timeout_event_fc2.trigger();

              // Spec violation: InitFC2_P not received within the interval
              `uvm_error("WDOG",
                $sformatf(
                  "[%s] FC2_TIMEOUT: InitFC2 set (P+NP+Cpl) not started within %0d cycles (%0d us). ",
                  role.name(), cfg.init_rx_interval_cycles,
                  cfg.init_rx_interval_cycles / 1000))
            end
          end : timer_thread

          begin : reset_thread
            @fc2_set_started;
            `uvm_info("WDOG",
              $sformatf("[%s] FC2_RESET : InitFC2_P received.", role.name()),
              UVM_HIGH)
          end : reset_thread

          begin : exit_thread
            wait (curr_state != DL_INIT_FC2);
          end : exit_thread

        join_any
        disable fork;

        if (curr_state != DL_INIT_FC2) break;
      end

      `uvm_info("WDOG",
        $sformatf("[%s] FC2_DISARMED : left DL_INIT_FC2.", role.name()),
        UVM_MEDIUM)

      wait (curr_state != DL_INIT_FC2);
    end
  endtask


  // Analysis port callbacks


  // Called by the state_mgr's state_ap (via env connect_phase)
  virtual function void write_wd_state(pcie_dlcmsm_state_e new_state);
    curr_state = new_state;
  endfunction

  // Called by the RX monitor's mon_rx_ap (via env connect_phase)
  // Only the leading DLLP of each round (the _P variant) resets the timer,
  // because the spec's 34 µs interval is measured between successive sets.
  virtual function void write_wd_rx(pcie_dll_base_seq_item item);
    pcie_dll_dllp_seq_item dllp_item;

    if (!$cast(dllp_item, item)) return;  // ignore non-DLLP items

    case (dllp_item.dllp_type)
      DLLP_FEATURE_REQ: begin
        // Every Feature DLLP resets the feature watchdog
        if (curr_state == DL_FEATURE_EXCH)
          -> feature_dllp_received;
      end
      DLLP_INITFC1_P: begin
        if (curr_state == DL_INIT_FC1)
          -> fc1_set_started;
      end
      DLLP_INITFC2_P: begin
        if (curr_state == DL_INIT_FC2)
          -> fc2_set_started;
      end
      default: ; // all other DLLP types are not timer-reset triggers
    endcase
  endfunction

endclass : pcie_dll_fc_watchdog
