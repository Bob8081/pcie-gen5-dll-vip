class pcie_dll_DL_INIT_FC1 extends pcie_dll_base_state;

    bit rx_p;
    bit rx_np;
    bit rx_cpl;
    uvm_event finished;

    pcie_dll_init1_seq init1_seq;


    pcie_dll_dllp_seq_item dllp_item_rx;
    

    `uvm_object_utils(pcie_dll_DL_INIT_FC1)


    function new(string name = "pcie_dll_DL_INIT_FC1");
        super.new(name);
        finished = new("finished");
    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("INITFC1_STATE", $sformatf("_____________%s: Entered DL_INIT_FC1 state______________", manager.role.name()), UVM_LOW)
        
        

        init1_seq = pcie_dll_init1_seq::type_id::create("init1_seq");

        fork 
        begin
            init1_seq.start(manager.dllp_sequencer);
        end

        begin //thread 2 to montior incoming packets
            forever 
            begin 

                if (manager.my_cfg.counter_fc1 == 3) 
                begin
                    manager.my_cfg.fi1_set = 1;
                    `uvm_info("INITFC1_STATE", $sformatf("%s: recieved prefect  triplets, setting fi1_set flag to 1", manager.role.name()), UVM_HIGH)
                    break; 
                   
                end

                else if ((rx_p && rx_np && rx_cpl))
                begin 
                    manager.my_cfg.fi1_set = 1;
                    `uvm_info("INITFC1_STATE", $sformatf("%s: All three DLLP types recieved, setting fi1_set flag to 1", manager.role.name()), UVM_HIGH)
                    break;
                end

                else
                begin
                    manager.dllp_fifo.get(dllp_item_rx);

                    
                    if ( (dllp_item_rx.dllp_type == DLLP_INITFC1_P) || (dllp_item_rx.dllp_type == DLLP_INITFC2_P))
                    begin

                        if (!rx_p)
                        begin   
                            manager.partner_cfg.set_credits_value(dllp_item_rx.dllp_type,dllp_item_rx.hdr_FC,dllp_item_rx.data_FC,
                                                                    dllp_item_rx.hdr_scale, dllp_item_rx.data_scale);
                            rx_p = 1;
                        end 

                        if(dllp_item_rx.dllp_type == DLLP_INITFC1_P) 
                        begin
                            manager.my_cfg.counter_fc1 = 1;
                            `uvm_info("INITFC1_STATE", $sformatf("%s: Received expected FC1 DLLP POSTED, count: %0d",
                                                        manager.role.name(), manager.my_cfg.counter_fc1), UVM_HIGH)
                        end
                        else 
                        begin
                            manager.my_cfg.counter_fc1 = 0; 
                        end
                    end//end of posted case

                    else if ((dllp_item_rx.dllp_type == DLLP_INITFC1_NP) || (dllp_item_rx.dllp_type == DLLP_INITFC2_NP))
                    begin
                        if (!rx_np)
                        begin
                           manager.partner_cfg.set_credits_value(dllp_item_rx.dllp_type,dllp_item_rx.hdr_FC,dllp_item_rx.data_FC,
                                                                    dllp_item_rx.hdr_scale, dllp_item_rx.data_scale);
                            rx_np = 1;
                        end
                        
                        if ((dllp_item_rx.dllp_type == DLLP_INITFC1_NP) && (manager.my_cfg.counter_fc1 == 1))
                        begin
                            manager.my_cfg.counter_fc1++;
                            `uvm_info("INITFC1_STATE", $sformatf("%s: Received expected FC1 DLLP NON_POSTED, count: %0d",
                                                        manager.role.name(), manager.my_cfg.counter_fc1), UVM_HIGH)
                        end
                        else 
                        begin
                            manager.my_cfg.counter_fc1 =0;
                
                        end 
                    end   //end of non posted case

                    else if ((dllp_item_rx.dllp_type == DLLP_INITFC1_CPL) || (dllp_item_rx.dllp_type == DLLP_INITFC2_CPL))
                    begin
                        if (!rx_cpl)
                        begin
                            manager.partner_cfg.set_credits_value(dllp_item_rx.dllp_type,dllp_item_rx.hdr_FC,dllp_item_rx.data_FC,
                                                                    dllp_item_rx.hdr_scale, dllp_item_rx.data_scale);
                            rx_cpl = 1;
                        end 
                        
                        if((dllp_item_rx.dllp_type == DLLP_INITFC1_CPL) && (manager.my_cfg.counter_fc1==2)) 
                        begin
                            manager.my_cfg.counter_fc1++;
                            `uvm_info("INITFC1_STATE", $sformatf("%s: Received expected FC1 Completion, count: %0d",
                                                        manager.role.name(), manager.my_cfg.counter_fc1), UVM_HIGH)
                        end
                        else 
                        begin  
                            manager.my_cfg.counter_fc1 =0;
                        end
                    end // end of compeletion state
                    else // else for any non initfc packet types recieved in initfc1 state
                    begin
                        manager.my_cfg.counter_fc1 =0;
                    end
                        manager.counters.counter_fc1 = manager.my_cfg.counter_fc1;
                        manager.counters.counter_fc2 = 0;
                        manager.fc_pkt_counter_ap.write(manager.counters);
                        `uvm_info("INITFC1_STATE", $sformatf("%s: Received DLLP type: %s, counter_fc1: %0d",
                                                        manager.role.name(), dllp_item_rx.dllp_type, manager.my_cfg.counter_fc1), UVM_LOW)
                end // big else
            end // forever loop



            next_state = DL_INIT_FC2;
            finished.trigger();

        end //end of thread 2 to monitor incoming packets

        
        begin //thread 3 to monitor the linkup signal 
            if(manager.lnk_cfg.pl_up) //stay in the active state as long as the link is up
            begin
                manager.lnk_cfg.pl_realesed.wait_trigger();
                `uvm_info("INITFC1_STATE", $sformatf("%s: Link is down, moving back to DL_INACTIVE...", manager.role.name()), UVM_HIGH)
                next_state = DL_INACTIVE;
            end
            else 
            begin 
                `uvm_info("INITFC1_STATE", $sformatf("%s: Link is down, moving back to DL_INACTIVE...", manager.role.name()), UVM_HIGH)
                next_state = DL_INACTIVE;
            end
            finished.trigger();
        end //end of thread 3
        
        join_none

        

        finished.wait_trigger(); // wait till any protocol of the two completes and triggers the event

        //kill the running sequence before transitiong so you don't keep sending initfc1 after transitiong
        init1_seq.kill();
        

        disable fork; //kill the threads too so you do clean transition

        
        manager.change_state(next_state); 

    endtask

endclass : pcie_dll_DL_INIT_FC1