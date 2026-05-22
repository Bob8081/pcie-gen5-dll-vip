class pcie_dll_DL_INIT_FC2 extends pcie_dll_base_state;

   
    uvm_event finished;

    pcie_dll_init2_seq init2_seq;
  
    pcie_dll_dllp_seq_item dllp_item_rx;
    pcie_dll_tlp_seq_item tlp_item_rx;

    `uvm_object_utils(pcie_dll_DL_INIT_FC2)

    
    function new(string name = "pcie_dll_DL_INIT_FC2");
        super.new(name);
    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("INITFC2_STATE", "Entered DL_INIT_FC2 state", UVM_LOW)
       

        finished=new("finished");

        init2_seq = pcie_dll_init2_seq::type_id::create("init2_seq");

        fork begin //TODO : let teh sequence run forever i will kill it here after finishing anyway 
        
        init2_seq.start(manager.dllp_sequencer);

        end

        begin
        forever 
        begin 

            if (manager.my_cfg.counter_fc2 == 3) begin
                `uvm_info("INITFC2_STATE", "Counter_fc 2 = 3 .", UVM_LOW)
                break;
            end

            else begin
                manager.dllp_fifo.get(dllp_item_rx);

                // TODO : to be added for protocol compliance 
                //if (manager.tlp_fifo.get(tlp_item_rx))begin
                //  break;
                //end

                if (dllp_item_rx.dllp_type == DLLP_INITFC2_P)
                begin

                    if(manager.my_cfg.counter_fc2 == 0) 
                    begin
                    
                        if (!(dllp_item_rx.hdr_FC == manager.dyn_cfg.partner_credits[FC_POSTED].hdr_limit))
                        begin
                            `uvm_error("CREDITS_ERR_INITFC2",$sformatf("recieved wrong POSTED HDR CREDITS, real value = %d",manager.dyn_cfg.partner_credits[FC_POSTED].hdr_limit))     
                        end

                        manager.my_cfg.counter_fc2++;
                        `uvm_info("INITFC2_STATE", $sformatf("Received expected FC2 DLLP POSTED, count: %0d", manager.my_cfg.counter_fc2), UVM_LOW)
                    end // end of IN_ORDER posted recieved
                    else 
                    begin  
                        `uvm_error("INITFC2_ERR",$sformatf("recieved OUT_OF_ORDER packet of type : %s",dllp_item_rx.dllp_type))
                    end 
                end//end of posted case

                else if (dllp_item_rx.dllp_type == DLLP_INITFC2_NP)
                begin
                    if (manager.my_cfg.counter_fc2 == 1)
                    begin
                      
                        if (!(dllp_item_rx.hdr_FC == manager.dyn_cfg.partner_credits[FC_NON_POSTED].hdr_limit))
                        begin
                            `uvm_error("CREDITS_ERR_INITFC2",$sformatf("recieved wrong NON_POSTED HDR CREDITS, real value = %d",manager.dyn_cfg.partner_credits[FC_NON_POSTED].hdr_limit))     
                        end
                       
                        manager.my_cfg.counter_fc2++;
                        `uvm_info("INITFC2_STATE", $sformatf("Received expected FC2 DLLP NON_POSTED, count: %0d", manager.my_cfg.counter_fc2), UVM_LOW)
                    end
                    else 
                    begin
                        manager.my_cfg.counter_fc2 = 0;
                        `uvm_error("INITFC2_ERR",$sformatf("recieved OUT_OF_ORDER packet of type : %s",dllp_item_rx.dllp_type))
                    end 
                end   //end of non posted case

                else if (dllp_item_rx.dllp_type == DLLP_INITFC2_CPL)
                begin
                    
                    if(manager.my_cfg.counter_fc2 == 2) 
                    begin
                        
                        if (!(dllp_item_rx.hdr_FC == manager.dyn_cfg.partner_credits[FC_CPL].hdr_limit))
                        begin
                            `uvm_error("CREDITS_ERR_INITFC2",$sformatf("recieved wrong CPL HDR CREDITS, real value = %d",manager.dyn_cfg.partner_credits[FC_CPL].hdr_limit))     
                        end
                        
                        manager.my_cfg.counter_fc2++;
                        `uvm_info("INITFC2_STATE", $sformatf("Received expected FC2 DLLP CPL, count: %0d", manager.my_cfg.counter_fc2), UVM_LOW)
                    end
                    else 
                    begin  
                        manager.my_cfg.counter_fc2 = 0;
                        `uvm_error("INITFC2_ERR",$sformatf("recieved OUT_OF_ORDER packet of type : %s",dllp_item_rx.dllp_type))
                    end
                end // end of compeletion state
                else // else for any non initfc1 packet types recieved in initfc1 state
                begin
                    manager.my_cfg.counter_fc2 = 0;
                    `uvm_error("INITFC2_ERR",$sformatf("recieved WRONG STATE DLLP of type : %s in INITFC2_STATE",dllp_item_rx.dllp_type))
                end
            end // big else
            end //forever loop

            next_state = DL_ACTIVE;
            finished.trigger();

        end//end of thread 2
        begin //thread 3 : upon tlp recieving move to active state directly and skip initfc2 protocol
            manager.tlp_fifo.get(tlp_item_rx);
            next_state = DL_ACTIVE;
            `uvm_info("INITFC2_STATE", "Received TLP during INITFC2, transitioning to ACTIVE state.", UVM_LOW)
            finished.trigger();
        end
       //TODO : add forth fork to  check for the pl_linkup signal and set next state to DL_INACTIVE whenever the link is down

    join_none

    //TODO : here let the recieving thread only decide the transition to the next state don't make it join_any 

        finished.wait_trigger(); // wait till any protocol of the two completes and triggers the event

        //kill the running sequence before transitiong so you don't keep sending initfc1 after transitiong
        init2_seq.kill();
        

        disable fork; //kill the threads too so you do clean transition
   
       
        manager.change_state(next_state); 
        
    endtask

endclass : pcie_dll_DL_INIT_FC2