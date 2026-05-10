//state manager class to handle all the states in the Data Link Layer
class pcie_dll_state_mgr extends uvm_component;
    `uvm_component_utils(pcie_dll_state_mgr);
        
    pcie_dll_role_e role;

    uvm_analysis_imp #(pcie_dll_base_seq_item, pcie_dll_state_mgr) dllp_export; //connected to the monitor on the agent level

    pcie_dll_seqr dllp_sequencer; //to be a handle to the sequencer of the agent to be able to send from the state manager if needed, and to be able to pass it to the states if needed

    pcie_dll_dllp_seq_item dllp_item;
    pcie_dll_tlp_seq_item tlp_item; 
    
    pcie_dll_env_cfg cfg; //to hold the configuration of the environment to be used in the state manager and passed to the states when needed, to decide the flow based on the features supported
    
    uvm_tlm_fifo#(pcie_dll_dllp_seq_item) dllp_fifo; //for dllp-only storage 

    //TODO: add tlp fifo if needed in the future

    pcie_dll_base_state current_state; //handle for the current state to track the state and to be accesed by the testbench
    
    pcie_dlcmsm_state_e dlsm_state; //to track the current state of the DLCM state machine, which is used in some states to decide the next steps

    uvm_analysis_port #(pcie_dlcmsm_state_e) state_ap; //broadcast state changes to the scoreboard

    uvm_event target_reached; //to be triggered when the state machine reaches the target state (DL_ACTIVE) to let the testbench know about it and to check the coverage at that point

    // Posted credits
    int unsigned partner_hdr_fc_p_limit;
    int unsigned partner_data_fc_p_limit;

    // Non-Posted credits
    int unsigned partner_hdr_fc_np_limit;
    int unsigned partner_data_fc_np_limit;

    // Completion credits
    int unsigned partner_hdr_fc_cpl_limit;
    int unsigned partner_data_fc_cpl_limit;

    function new(string name = "pcie_dll_state_mgr", uvm_component parent = null);
        super.new(name, parent);
        dllp_fifo = new("dllp_fifo", this);
        dllp_export = new("dllp_export", this);
        target_reached = new("target_reached");
        state_ap = new("state_ap", this);
    endfunction

    function void write (pcie_dll_base_seq_item item);
      if($cast(dllp_item, item)) begin
        //TODO : check crc and drop it if it is wrong

        dllp_fifo.try_put(dllp_item); //non-blocking becuse the write is a function , to avoid compiling error
        
      end
      else
        begin
            `uvm_fatal("ITEM_ERR", $sformatf("Received item of type %s, expected pcie_dll_dllp_seq_item", item.get_type_name()))
        end
      //TODO: handle tlp items if needed in the future
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        //TODO : make two separate events for rc and ep
        if(!uvm_config_db#(uvm_event)::get(this, "", "event", target_reached)) begin
            `uvm_fatal("NOEV", "No event found in config_db for pcie_dll_state_mgr.")
        end
    endfunction

   
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction
   
    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        `uvm_info("STATE_CTRL", "Starting State Manager run_phase", UVM_LOW)
        dlsm_state = DL_INACTIVE; //start with the idle state, and the state will decide when to change to other states
        change_state(dlsm_state); //start with the inactive state, and the state will decide when to change to other states
        
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
        
        dlsm_state = new_state; //update the current state variable to the new state

        // Broadcast the new state to the scoreboard
        state_ap.write(dlsm_state);

        //pass the satate manager handle to the state created to let it access the state manager and its methods and properties
        current_state.start_state(this); 

    endtask

    function void set_credits_value(pcie_dllp_type_e t, int unsigned hdr_fc, int unsigned data_fc);

        if (t == DLLP_INITFC1_P) begin
            partner_hdr_fc_p_limit = hdr_fc;
            partner_data_fc_p_limit = data_fc;
        end
        else if (t == DLLP_INITFC1_NP) begin
            partner_hdr_fc_np_limit = hdr_fc;
            partner_data_fc_np_limit = data_fc;
        end
        else if (t == DLLP_INITFC1_CPL) begin
            partner_hdr_fc_cpl_limit = hdr_fc;
            partner_data_fc_cpl_limit = data_fc;
        end
        `uvm_info("CRD SAVED",$sformatf("Recieved the credits for %s \n current credits saved for each type : \n Posted : hdr = %d , data = %d \n NON_Posted : hdr =%d, data= %d \n Compeletion : hdr = %d , data= %d ",
                    t.name(),partner_hdr_fc_p_limit,partner_data_fc_p_limit,partner_hdr_fc_np_limit,partner_data_fc_np_limit,partner_hdr_fc_cpl_limit,
                    partner_data_fc_cpl_limit),UVM_LOW)
    endfunction

    virtual task send_to_driver(pcie_dll_base_seq_item packet); //to be used in case of the state decides what to send next 
        send_single_packet single_seq;
        single_seq = send_single_packet::type_id::create("single_seq");
        single_seq.item_to_send = packet;
        single_seq.start(dllp_sequencer); 
    endtask

    
endclass