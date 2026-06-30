class pcie_dll_DL_ACTIVE extends pcie_dll_base_state;


    pcie_dll_tlp_seq_item tlp_item;
    pcie_dll_tlp_seq tlp_seq;
    `uvm_object_utils(pcie_dll_DL_ACTIVE)


    function new(string name = "pcie_dll_DL_ACTIVE");
        super.new(name);
    endfunction

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("ACTIVE_STATE", "Entered DL_ACTIVE state", UVM_LOW)
        tlp_seq = pcie_dll_tlp_seq::type_id::create("tlp_seq");
        tlp_seq.start(manager.dllp_sequencer);
        manager.target_reached.trigger(); //trigger the event to let the testbench know that we have reached the target state, which is used for coverage purposes and to control the flow in the testbench
        if(manager.lnk_cfg.pl_up) //stay in the active state as long as the link is up
        begin
            `uvm_info("ACTIVE_STATE", "Link is up, staying in DL_ACTIVE state...", UVM_LOW)
            tlp_seq.kill();
            manager.lnk_cfg.pl_realesed.wait_trigger();
            next_state = DL_INACTIVE;
            manager.change_state(next_state);
        end
        //TODO: here we can add some logic to decide the next state based on the test scenario, for now we will just go back to the inactive state when the link goes down
        //TODO: here add the active state logic in next stage
    endtask

endclass : pcie_dll_DL_ACTIVE