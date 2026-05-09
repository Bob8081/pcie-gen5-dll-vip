class pcie_dll_DL_INIT_FC2 extends pcie_dll_base_state;

   
    uvm_event finished;

    pcie_dll_init2_seq init2_seq;
    //for monitoring the recieved sequence of DLLPs
    int counter;
    pcie_dll_dllp_seq_item dllp_item_rx;

    `uvm_object_utils(pcie_dll_DL_INIT_FC2)

    
    function new(string name = "pcie_dll_DL_INIT_FC2");
        super.new(name);
    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("INITFC2_STATE", "Entered DL_INIT_FC2 state", UVM_LOW)

        counter = 0;

        finished=new("finished");

        init2_seq = pcie_dll_init2_seq::type_id::create("init2_seq");

        fork begin //TODO : let teh sequence run forever i will kill it here after finishing anyway 
        
        init2_seq.start(manager.dllp_sequencer);

        end

        begin
        forever begin 
            if (counter == 3) begin
                break;
            end

            else begin
                manager.dllp_fifo.get(dllp_item_rx);

                // TODO : to be added for protocol compliance 
                //if (manager.tlp_fifo.get(tlp_item_rx))begin
                //  break;
                //end

                if(counter==0)
                begin
                    if (dllp_item_rx.dllp_type == DLLP_INITFC2_P) begin
                    counter++;
                    `uvm_info("INITFC2_STATE", $sformatf("Received expected FC2 DLLP POSTED, count: %0d", counter), UVM_LOW)
                    end
                    else
                        `uvm_error("INITFC2_STATE", $sformatf("Received unexpected packet of type : %s, resetting counter, count: %0d", dllp_item_rx.dllp_type.name, counter))
                end
                else if(counter==1)
                begin
                    if (dllp_item_rx.dllp_type == DLLP_INITFC2_NP)
                    begin
                        counter++;
                        `uvm_info("INITFC2_STATE", $sformatf("Received expected FC2 DLLP NON-POSTED, count: %0d", counter), UVM_LOW)
                    end
                    else if (dllp_item_rx.dllp_type == DLLP_INITFC2_P)
                    begin
                        `uvm_error("INITFC2_STATE", $sformatf("Received duplicated FC2 DLLP POSTED, count: %0d", counter))
                    end
                    else 
                    begin
                        counter=0;
                        `uvm_error("INITFC2_STATE", $sformatf("Received unexpected packet of type : %s, resetting counter, count: %0d", dllp_item_rx.dllp_type.name, counter))
                    end
                end
                else if (counter==2) 
                begin
                    if (dllp_item_rx.dllp_type == DLLP_INITFC2_CPL)
                    begin
                        counter++;
                        `uvm_info("INITFC2_STATE", $sformatf("Received expected FC2 DLLP COMPLETION, count: %0d", counter), UVM_LOW)
                    end
                    else if (dllp_item_rx.dllp_type == DLLP_INITFC2_NP)
                    begin
                        `uvm_error("INITFC2_STATE", $sformatf("Received duplicated FC2 DLLP NON-POSTED, count: %0d", counter))
                    end
                    else if (dllp_item_rx.dllp_type == DLLP_INITFC2_P) 
                    begin
                        counter = 1 ;
                        `uvm_error("INITFC2_STATE", $sformatf("Received out-of-order FC2 DLLP POSTED, count: %0d", counter))                        
                    end
                    else
                    begin
                        counter=0;
                        `uvm_error("INITFC2_STATE", $sformatf("Received unexpected packet of type: %s, resetting counter, count: %0d", dllp_item_rx.dllp_type.name, counter))
                    end
                end
                    
            
                end
            end//edn of forever loop

            next_state = DL_ACTIVE;
            finished.trigger();

        end//end of thread 2

       //TODO : add third fork to  check for the pl_linkup signal and set next state to DL_INACTIVE whenever the link is down

    join_none

    //TODO : here let the recieving thread only decide the transition to the next state don't make it join_any 

        finished.wait_trigger(); // wait till any protocol of the two completes and triggers the event

        //kill the running sequence before transitiong so you don't keep sending initfc1 after transitiong
        init2_seq.kill();
        

        disable fork; //kill the threads too so you do clean transition
   
       
        manager.change_state(next_state); 
        
    endtask

endclass : pcie_dll_DL_INIT_FC2