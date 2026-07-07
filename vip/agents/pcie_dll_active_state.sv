class pcie_dll_DL_ACTIVE extends pcie_dll_base_state;


    pcie_dll_tlp_seq_item tlp_item;
    pcie_dll_tlp_seq tlp_seq;
    uvm_event finished;
    `uvm_object_utils(pcie_dll_DL_ACTIVE)


    function new(string name = "pcie_dll_DL_ACTIVE");
        super.new(name);
        finished = new("finished");
    endfunction

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("ACTIVE_STATE", $sformatf("%s: Entered DL_ACTIVE state", manager.role.name()), UVM_LOW)
        tlp_seq = pcie_dll_tlp_seq::type_id::create("tlp_seq");
        fork 
        begin 
            tlp_seq.start(manager.dllp_sequencer);
        end
        begin
            if(manager.lnk_cfg.pl_up) //stay in the active state as long as the link is up
            begin
                `uvm_info("ACTIVE_STATE", $sformatf("%s: Link is up, staying in DL_ACTIVE state...", manager.role.name()), UVM_HIGH)
                manager.lnk_cfg.pl_realesed.wait_trigger();
                next_state = DL_INACTIVE;
                finished.trigger();
            end
            else
            begin
                `uvm_info("ACTIVE_STATE", $sformatf("%s: Link is down, transitioning to DL_INACTIVE state...", manager.role.name()), UVM_HIGH)
                next_state = DL_INACTIVE;
                finished.trigger();
            end
        end
        join_none

        finished.wait_trigger();
        tlp_seq.kill();
        disable fork;
            
        manager.change_state(next_state); 
    endtask

endclass : pcie_dll_DL_ACTIVE