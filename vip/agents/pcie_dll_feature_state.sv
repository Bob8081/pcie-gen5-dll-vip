class pcie_dll_DL_FEATURE_EXCH extends pcie_dll_base_state;

    pcie_dll_dllp_seq_item dllp_item_rx;

    pcie_dll_feature_seq feature_seq;

    bit feature_support_sent;

    uvm_event finished;

    `uvm_object_utils(pcie_dll_DL_FEATURE_EXCH)

    
    function new(string name = "pcie_dll_DL_FEATURE_EXCH");
        super.new(name);

        

        finished= new();

    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        //initialize the fields on state entry
        feature_support_sent = 0;
        manager.partner_cfg.partner_feature_valid = 0;
        manager.partner_cfg.partner_feature_support = 0;

        `uvm_info("STATE", "Entered DL_FEATURE_EXCH state", UVM_LOW)
        `uvm_info("FEATURE_STATE", $sformatf("Feature Exchange starting. with remote_feature_support = %b, remote_feature_valid = %b", 
                                            manager.partner_cfg.partner_feature_support, manager.partner_cfg.partner_feature_valid), UVM_LOW)

        fork 
        begin
            forever
            begin
                feature_seq = pcie_dll_feature_seq::type_id::create("feature_seq");
                feature_seq.start(manager.dllp_sequencer); 
            end
        end

        begin //thread 2 : for receiving the feauter dllps
            forever
            begin 
                manager.dllp_fifo.get(dllp_item_rx);
                if (dllp_item_rx.dllp_type == DLLP_FEATURE_REQ)
                begin
                    feature_support_sent = dllp_item_rx.feature_ack;
                    manager.partner_cfg.partner_feature_support = dllp_item_rx.feature_support;
                    manager.partner_cfg.partner_feature_valid = 1;
                    feature_seq.seq_feature_ack = 1;
                    `uvm_info("FEATURE_STATE", $sformatf("Recieived FEATURE DLLP from partner, feature support = %b, feature_ack=%b", 
                                                        dllp_item_rx.feature_support, dllp_item_rx.feature_ack), UVM_LOW)
                end
                else if (dllp_item_rx.dllp_type == DLLP_INITFC1_P)
                begin
                    finished.trigger();
                end
                else
                begin
                    `uvm_error("FEATURE_ERR",$sformatf("recieved WRONG STATE DLLP of type : %s in FEATURE_STATE",dllp_item_rx.dllp_type))
                end
            end
        end
        
        join_none

        //exit conditions threads
        fork 
        begin
            finished.wait_trigger();
        end
        begin
            wait(feature_support_sent && manager.partner_cfg.partner_feature_valid ); 
        end
        join_any
        
        //kill the seq and disbale all the forks before moving to next state
        feature_seq.kill();

        disable fork;

        `uvm_info("FEATURE_STATE", $sformatf("Feature Exchange Completed, moving to next state. with remote_feature_support = %b, remote_feature_valid = %b", 
                                            manager.partner_cfg.partner_feature_support, manager.partner_cfg.partner_feature_valid), UVM_LOW)
        
        next_state = DL_INIT_FC1;
        manager.change_state(next_state); 
    endtask

endclass : pcie_dll_DL_FEATURE_EXCH