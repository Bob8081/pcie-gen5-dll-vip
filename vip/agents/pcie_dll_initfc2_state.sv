class pcie_dll_DL_INIT_FC2 extends pcie_dll_base_state;

   
    uvm_event finished;

    pcie_dll_init2_seq init2_seq;
  
    pcie_dll_dllp_seq_item dllp_item_rx;
    pcie_dll_tlp_seq_item tlp_item_rx;

    `uvm_object_utils(pcie_dll_DL_INIT_FC2)

    
    function new(string name = "pcie_dll_DL_INIT_FC2");
        super.new(name);
        finished=new("finished");
    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("INITFC2_STATE", $sformatf("_____________%s: Entered DL_INIT_FC2 state______________", manager.role.name()), UVM_LOW)
       

        

        init2_seq = pcie_dll_init2_seq::type_id::create("init2_seq");

        fork begin 
        init2_seq.start(manager.dllp_sequencer);
        end
        begin
        forever 
        begin 

            if (manager.my_cfg.counter_fc2 == 3) begin
                manager.my_cfg.fi2_set = 1;
                `uvm_info("INITFC2_STATE", $sformatf("%s: Counter_fc 2 = 3, setting fi2_set flag to 1",
                                            manager.role.name()), UVM_HIGH)
                break;
            end

            else begin
                manager.dllp_fifo.get(dllp_item_rx);

                if (dllp_item_rx.dllp_type == DLLP_INITFC2_P)
                begin

                    if(manager.my_cfg.counter_fc2 == 0) 
                    begin

                        manager.my_cfg.counter_fc2++;
                        `uvm_info("INITFC2_STATE", $sformatf("%s: Received expected FC2 DLLP POSTED, count: %0d",
                                                    manager.role.name(), manager.my_cfg.counter_fc2), UVM_HIGH)
                    end // end of IN_ORDER posted recieved
                    else 
                    begin  
                        manager.my_cfg.counter_fc2 = 1 ;
                    end 
                end//end of posted case

                else if (dllp_item_rx.dllp_type == DLLP_INITFC2_NP)
                begin
                    if (manager.my_cfg.counter_fc2 == 1)
                    begin
                      
                        manager.my_cfg.counter_fc2++;
                        `uvm_info("INITFC2_STATE", $sformatf("%s: Received expected FC2 DLLP NON_POSTED, count: %0d", 
                                                    manager.role.name(), manager.my_cfg.counter_fc2), UVM_HIGH)
                    end
                    else 
                    begin
                        manager.my_cfg.counter_fc2 = 0;
                    end 
                end   //end of non posted case

                else if (dllp_item_rx.dllp_type == DLLP_INITFC2_CPL)
                begin
                    
                    if(manager.my_cfg.counter_fc2 == 2) 
                    begin
                        
                        manager.my_cfg.counter_fc2++;
                        `uvm_info("INITFC2_STATE", $sformatf("%s: Received expected FC2 DLLP CPL, count: %0d", 
                                                    manager.role.name(), manager.my_cfg.counter_fc2), UVM_HIGH)
                    end
                    else 
                    begin  
                        manager.my_cfg.counter_fc2 = 0;
                    end
                end // end of compeletion state
                else // else for any non initfc2 packet types recieved in initfc2 state
                begin
                    manager.my_cfg.counter_fc2 = 0;
                end

                        manager.counters.counter_fc2 = manager.my_cfg.counter_fc2;
                        manager.counters.counter_fc1 = 0;
                        manager.fc_pkt_counter_ap.write(manager.counters);
            end // big else
            end //forever loop

            next_state = DL_ACTIVE;
            finished.trigger();

        end//end of thread 2
        begin //thread 3 : upon tlp recieving move to active state directly and skip initfc2 protocol
            manager.tlp_fifo.get(tlp_item_rx);
            next_state = DL_ACTIVE;
            manager.my_cfg.fi2_set = 1;
            `uvm_info("INITFC2_STATE", $sformatf("%s: Received TLP during INITFC2, transitioning to ACTIVE state and setting fi2_set flag to 1.",
                                        manager.role.name()), UVM_HIGH)
            finished.trigger();
        end//end of thread 3


       begin //thread 4 to monitor the linkup signal 
            if(manager.lnk_cfg.pl_up) //stay in the active state as long as the link is up
            begin
                manager.lnk_cfg.pl_realesed.wait_trigger();
                `uvm_info("INITFC2_STATE", $sformatf("%s: Link is down, moving back to DL_INACTIVE...", manager.role.name()), UVM_HIGH)
                next_state = DL_INACTIVE;
            end
            else 
            begin 
                `uvm_info("INITFC2_STATE", $sformatf("%s: Link is down, moving back to DL_INACTIVE...", manager.role.name()), UVM_HIGH)
                next_state = DL_INACTIVE;
            end
            finished.trigger();
        end //end of thread 4
    join_none

    

        finished.wait_trigger(); // wait till any protocol of the two completes and triggers the event

        //kill the running sequence before transitiong so you don't keep sending initfc1 after transitiong
        init2_seq.kill();
        

        disable fork; //kill the threads too so you do clean transition
   
       
       
        manager.change_state(next_state); 
        
    endtask

endclass : pcie_dll_DL_INIT_FC2
