//state manager class to handle all the states in the Data Link Layer
class pcie_dll_state_mgr extends uvm_component;
    `uvm_component_utils(pcie_dll_state_mgr);

    pcie_dll_role_e role;

    uvm_analysis_imp #(pcie_dll_base_seq_item, pcie_dll_state_mgr) dllp_export; //connected to the monitor on the agent level
    uvm_analysis_port #(pcie_state_mgr_counters_s) st_mgr_counter_ap;

    pcie_dll_seqr dllp_sequencer; //to be a handle to the sequencer of the agent to be able to send from the state manager if needed, and to be able to pass it to the states if needed

    pcie_dll_dllp_seq_item dllp_item;
    pcie_dll_tlp_seq_item tlp_item;
    pcie_state_mgr_counters_s counters;


    uvm_tlm_fifo#(pcie_dll_dllp_seq_item) dllp_fifo;
    uvm_tlm_fifo#(pcie_dll_tlp_seq_item) tlp_fifo;
    //TODO: add tlp fifo if needed in the future

    pcie_dll_base_state current_state; //handle for the current state to track the state and to be accesed by the testbench
    pcie_dll_partner_cfg partner_cfg;
    pcie_dll_env_cfg cfg;
    pcie_dll_my_cfg my_cfg;
    pcie_dll_link_cfg lnk_cfg;
    uvm_analysis_port #(pcie_dlcmsm_state_e) state_ap; //broadcast state changes to the scoreboard

    uvm_event target_reached; //to be triggered when the state machine reaches the target state (DL_ACTIVE) to let the testbench know about it and to check the coverage at that point



    function new(string name = "pcie_dll_state_mgr", uvm_component parent = null);
        super.new(name, parent);
        dllp_fifo = new("dllp_fifo", this);
        tlp_fifo = new("tlp_fifo", this);
        dllp_export = new("dllp_export", this);
        target_reached = new("target_reached");
        state_ap = new("state_ap", this);
        st_mgr_counter_ap = new("st_mgr_counter_ap", this);
    endfunction

    function void write (pcie_dll_base_seq_item item);
        if($cast(dllp_item, item))
        begin
            //TODO : check crc and drop it if it is wrong
            // if (dllp_item.verify_crc())
            // begin
                dllp_fifo.try_put(dllp_item); //non-blocking becuse the write is a function , to avoid compiling error
            // end
        end
        else if($cast(tlp_item,item))
        begin
            tlp_fifo.try_put(tlp_item);
        end
        else
        begin
            `uvm_fatal("ITEM_ERR", $sformatf("Received item of type %s, expected pcie_dll_dllp_seq_item or pcie_dll_tlp_seq_item", item.get_type_name()))
        end
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //each device's state manager in the vip gets a differnet instance of the event according to thier env
        if(!uvm_config_db#(uvm_event)::get(this, "", "event", target_reached)) begin
            `uvm_fatal("NOEV", $sformatf("No event found in config_db for %s state_manager.",role.name()))
        end

        if(!uvm_config_db#(pcie_dll_partner_cfg)::get(this, "", "partner_cfg", partner_cfg))begin
            `uvm_fatal("NOCFG",$sformatf("no partner_cfg found in teh config_db for %s state_manager",role.name()))
        end

        if (!uvm_config_db#(pcie_dll_my_cfg)::get(this, "", "my_cfg", my_cfg))begin
            `uvm_fatal("NOCFG",$sformatf("no my_cfg found in teh config_db for %s state_manager",role.name()))
        end
        if (!uvm_config_db#(pcie_dll_link_cfg)::get(this, "", "lnk_cfg", lnk_cfg))begin
            `uvm_fatal("NOCFG",$sformatf("no link cfg found in teh config_db for %s state_manager",role.name()))
        end
        partner_cfg.role=role;
        my_cfg.role=role;

    endfunction


    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info("STATE_CTRL", "Starting State Manager run_phase", UVM_LOW)
        change_state(DL_INACTIVE);
    endtask


    virtual task change_state(pcie_dlcmsm_state_e new_state);
        //create temporary object to contain the new state, and to check if the factory can create the state ordered before changing the current state handle
        uvm_object obj;
        string state_name = $sformatf("pcie_dll_%s", new_state.name());
        obj = uvm_factory::get().create_object_by_name(state_name, get_full_name(), state_name);

        if (obj == null) begin
            `uvm_fatal("STATE_ERR", $sformatf("Factory failed to create state: '%s'. check for typos and make sure the class has `uvm_object_utils", new_state.name()))
        end

        //for debugging purposes, to track state changes in the log
        `uvm_info("STATE_CTRL", $sformatf("Changing state from %s to %s", (current_state != null) ? current_state.get_full_name() : "None"   , new_state.name()), UVM_LOW)

        //crate the new state and check if it extends the correct base class
        if(!$cast(current_state, obj))begin
            `uvm_fatal("STATE_ERR", $sformatf("Failed to cast object '%s' to pcie_dll_state. make sure it extends the correct base class", new_state.name()))
        end

        my_cfg.dlsm_state = new_state; //update the current state variable to the new state

        my_cfg.view_state(); //debug line

        // Broadcast the new state to the scoreboard
        state_ap.write(my_cfg.dlsm_state);

        //pass the satate manager handle to the state created to let it access the state manager and its methods and properties
        current_state.start_state(this);

    endtask


    virtual task send_to_driver(pcie_dll_base_seq_item packet); //to be used in case of the state decides what to send next
        send_single_packet single_seq;
        single_seq = send_single_packet::type_id::create("single_seq");
        single_seq.item_to_send = packet;
        single_seq.start(dllp_sequencer);
    endtask


endclass