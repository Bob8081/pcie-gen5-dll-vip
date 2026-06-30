class pcie_dll_DL_INACTIVE extends pcie_dll_base_state;

    
    `uvm_object_utils(pcie_dll_DL_INACTIVE)

    
    function new(string name = "pcie_dll_DL_INACTIVE");
        super.new(name);
    endfunction 

    task start_state(pcie_dll_state_mgr manager);

        `uvm_info("INACTIVE_STATE", "Entered DL_INACTIVE state", UVM_LOW)
        manager.my_cfg.reset();
        manager.partner_cfg.reset();
        manager.dllp_fifo.flush();
        manager.tlp_fifo.flush();

        //TODO : here wait for the link up signal
        //TODO : add logic to check for the presence of the feature state (e.g. the configuration's scaled_support filed is set or not) and decide what is next state depepnding on it)
        while(!manager.lnk_cfg.pl_up)
        begin
            `uvm_info("INACTIVE_STATE", "Waiting for link to come up...", UVM_LOW)
            manager.lnk_cfg.pl_asserted.wait_trigger();
        end
        `uvm_info("INACTIVE_STATE", "Link is up, moving to next state...", UVM_LOW)
        if (manager.cfg.scaled_fc_supported )
        begin
            next_state = DL_FEATURE_EXCH;
        end
        else
        begin
            next_state= DL_INIT_FC1;
        end
        manager.change_state(next_state); 
    endtask 

endclass : pcie_dll_DL_INACTIVE