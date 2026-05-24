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
    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("STATE", "Entered DL_INIT_FC1 state", UVM_LOW)
        
        
        

        finished = new("finished");

        init1_seq = pcie_dll_init1_seq::type_id::create("init1_seq");

        fork 
        begin
            init1_seq.start(manager.dllp_sequencer);
        end

        begin
            forever 
            begin 

                if (manager.my_cfg.counter_fc1 == 3) 
                begin
                    //TODO :add event for setting the initfc1 flag and make it break the loop not the manager.my_cfg.counter_fc1 check (done)
                    //TODO : add check for initfc2 recieve and make it trigger the flag only  (done)
                    break;
                end

                else 
                begin 
                    //TODO : throw errors when the protocol is violated 
                    //TODO : add checks for the timing using the timing check in the sequences 
                    //TODO : add check for values of credits recieved is matched in each packet 


                    manager.dllp_fifo.get(dllp_item_rx);

                    if ((rx_p && rx_np && rx_cpl))
                    //if ((dllp_item_rx.dllp_type == DLLP_INITFC2_P) || (rx_p && rx_np && rx_cpl)) 
                    begin
                        break;
                    end
                    else if ( (dllp_item_rx.dllp_type == DLLP_INITFC1_P) || (dllp_item_rx.dllp_type == DLLP_INITFC2_P))
                    begin

                        if (rx_p)
                        begin 
                            //comparsion with the recieved not_scaled values with the actual not_scaled stored values
                            if (!(dllp_item_rx.hdr_FC == manager.dyn_cfg.partner_credits[FC_P].hdr_limit)) //TODO : add checks for the data_limit and hdr_scale and data_scale fields too (maybe use a temp. fc_struct to loop-check it)
                            begin
                                `uvm_error("CREDITS_ERR",$sformatf("recieved wrong POSTED HDR CREDITS, real value = %d",manager.dyn_cfg.partner_credits[FC_P].hdr_limit))     
                            end
                        end
                        else 
                        begin   
                            manager.dyn_cfg.set_credits_value(dllp_item_rx.dllp_type,dllp_item_rx.hdr_FC,dllp_item_rx.data_FC,
                                                                    dllp_item_rx.hdr_scale, dllp_item_rx.data_scale);
                            rx_p = 1;
                        end 

                        if(manager.my_cfg.counter_fc1==0) 
                        begin
                            manager.my_cfg.counter_fc1++;
                            `uvm_info("INITFC1_STATE", $sformatf("Received expected FC1 DLLP POSTED, count: %0d", manager.my_cfg.counter_fc1), UVM_LOW)
                        end // end of IN_ORDER posted recieved
                        else 
                        begin  
                            manager.my_cfg.counter_fc1 = 1 ;
                            `uvm_error("INITFC1_ERR",$sformatf("recieved OUT_OF_ORDER packet of type : %s",dllp_item_rx.dllp_type))
                        end 
                    end//end of posted case

                    else if ((dllp_item_rx.dllp_type == DLLP_INITFC1_NP) || (dllp_item_rx.dllp_type == DLLP_INITFC2_NP))
                    begin
                        if (rx_np)
                        begin
                            if (!(dllp_item_rx.hdr_FC == manager.dyn_cfg.partner_credits[FC_NP].hdr_limit))
                            begin
                                `uvm_error("CREDITS_ERR",$sformatf("recieved wrong NON_POSTED HDR CREDITS, real value = %d",manager.dyn_cfg.partner_credits[FC_NP].hdr_limit))     
                            end
                        end
                        else 
                        begin
                           manager.dyn_cfg.set_credits_value(dllp_item_rx.dllp_type,dllp_item_rx.hdr_FC,dllp_item_rx.data_FC,
                                                                    dllp_item_rx.hdr_scale, dllp_item_rx.data_scale);
                            rx_np = 1;
                        end
                        
                        if (manager.my_cfg.counter_fc1 == 1)
                        begin
                            manager.my_cfg.counter_fc1++;
                            `uvm_info("INITFC1_STATE", $sformatf("Received expected FC1 DLLP NON_POSTED, count: %0d", manager.my_cfg.counter_fc1), UVM_LOW)
                        end
                        else 
                        begin
                            manager.my_cfg.counter_fc1 =0;
                            `uvm_error("INITFC1_ERR",$sformatf("recieved OUT_OF_ORDER packet of type : %s",dllp_item_rx.dllp_type))
                        end 
                    end   //end of non posted case

                    else if ((dllp_item_rx.dllp_type == DLLP_INITFC1_CPL) || (dllp_item_rx.dllp_type == DLLP_INITFC2_CPL))
                    begin
                        if (rx_cpl)
                        begin
                            if (!(dllp_item_rx.hdr_FC == manager.dyn_cfg.partner_credits[FC_CPL].hdr_limit))
                            begin
                                `uvm_error("CREDITS_ERR",$sformatf("recieved wrong CPL HDR CREDITS, real value = %d",manager.dyn_cfg.partner_credits[FC_CPL].hdr_limit))     
                            end
                        end
                        else 
                        begin
                            manager.dyn_cfg.set_credits_value(dllp_item_rx.dllp_type,dllp_item_rx.hdr_FC,dllp_item_rx.data_FC,
                                                                    dllp_item_rx.hdr_scale, dllp_item_rx.data_scale);
                            rx_cpl = 1;
                        end 
                        
                        if(manager.my_cfg.counter_fc1==2) 
                        begin
                            manager.my_cfg.counter_fc1++;
                            `uvm_info("INITFC1_STATE", $sformatf("Received expected FC1 Completion, count: %0d", manager.my_cfg.counter_fc1), UVM_LOW)
                        end
                        else 
                        begin  
                            manager.my_cfg.counter_fc1 =0;
                            `uvm_error("INITFC1_ERR",$sformatf("recieved OUT_OF_ORDER packet of type : %s",dllp_item_rx.dllp_type))
                        end
                    end // end of compeletion state
                    else // else for any non initfc1 packet types recieved in initfc1 state
                    begin
                        manager.my_cfg.counter_fc1 =0;
                        `uvm_error("INITFC1_ERR",$sformatf("recieved WRONG STATE DLLP of type : %s in INITFC1_STATE",dllp_item_rx.dllp_type))
                    end
                end // big else
            end // forever loop



            next_state = DL_INIT_FC2;
            finished.trigger();

        end //end of thread 2

        //TODO : add third fork to  check for the pl_linkup signal and set next state to DL_INACTIVE whenever the link is down
        join_none

        //TODO : here let the recieving thread only decide the transition to the next state don't make it join_any

        finished.wait_trigger(); // wait till any protocol of the two completes and triggers the event

        //kill the running sequence before transitiong so you don't keep sending initfc1 after transitiong
        init1_seq.kill();
        

        disable fork; //kill the threads too so you do clean transition

        
        manager.change_state(next_state); 

    endtask

endclass : pcie_dll_DL_INIT_FC1