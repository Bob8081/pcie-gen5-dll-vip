class pcie_dll_DL_INIT_FC1 extends pcie_dll_base_state;

 
    uvm_event finished;

    pcie_dll_init1_seq init1_seq;

    //for monitoring the recieved sequence of DLLPS
    int counter;
    pcie_dll_dllp_seq_item dllp_item_rx;


    `uvm_object_utils(pcie_dll_DL_INIT_FC1)

    function new(string name = "pcie_dll_DL_INIT_FC1");
        super.new(name);
    endfunction 

    task start_state(pcie_dll_state_mgr manager);
        `uvm_info("STATE", "Entered DL_INIT_FC1 state", UVM_LOW)

        counter = 0;

        finished = new("finished");

        init1_seq = pcie_dll_init1_seq::type_id::create("init1_seq");

        fork 
        begin
        init1_seq.start(manager.dllp_sequencer);
        end

        begin
        forever begin 
            
            if (counter == 3) begin
                //TODO :add event for setting the initfc1 flag and make it break the loop not the counter check (done)
                //TODO : add check for initfc2 recieve and make it trigger the flag only  (done)
                break;
            end

            else 
            begin //TODO : throw errors when the protocol is violated 
                //TODO : add checks for the timing using the timing check in the sequences 
                //TODO : add check for values of credits recieved is matched in each packet 
                

                manager.dllp_fifo.get(dllp_item_rx);

                if ((dllp_item_rx.dllp_type == DLLP_INITFC2_P) || (dllp_item_rx.dllp_type == DLLP_INITFC2_NP) || (dllp_item_rx.dllp_type == DLLP_INITFC2_CPL)) 
                begin
                    
                    break;

                end

                else if(counter==0)
                begin

                    if (dllp_item_rx.dllp_type == DLLP_INITFC1_P) begin
                        counter++;
                        `uvm_info("INITFC1_STATE", $sformatf("Received expected FC1 DLLP POSTED, count: %0d", counter), UVM_LOW)
                    end

                    else 
                        `uvm_error("INITFC1_STATE", $sformatf("Received unexpected Packet of type : %s, resetting counter, count: %0d", dllp_item_rx.dllp_type.name, counter))
                    
                end

                else if(counter==1)

                begin
                    if (dllp_item_rx.dllp_type == DLLP_INITFC1_NP)
                    begin
                        counter++;
                        `uvm_info("INITFC1_STATE", $sformatf("Received expected FC1 DLLP NON-POSTED, count: %0d", counter), UVM_LOW)
                    end
                    else if (dllp_item_rx.dllp_type == DLLP_INITFC1_P)
                    begin
                        `uvm_error("INITFC1_STATE", $sformatf("Received duplicated FC1 DLLP POSTED, count: %0d", counter))
                    end
                    else 
                    begin
                        counter=0;
                        `uvm_error("INITFC1_STATE", $sformatf("Received unexpected Packet of type : %s, resetting counter, count: %0d", dllp_item_rx.dllp_type.name, counter))
                    end
                end
                else if (counter==2) 
                begin
                    if (dllp_item_rx.dllp_type == DLLP_INITFC1_CPL)
                    begin
                        counter++;
                        `uvm_info("INITFC1_STATE", $sformatf("Received expected FC1 DLLP COMPLETION, count: %0d", counter), UVM_LOW)
                    end
                    else if (dllp_item_rx.dllp_type == DLLP_INITFC1_NP)
                    begin
                        `uvm_error("INITFC1_STATE", $sformatf("Received duplicated FC1 DLLP NON-POSTED, count: %0d", counter))
                    end
                    else if (dllp_item_rx.dllp_type == DLLP_INITFC1_P)
                    begin
                        counter = 1 ;
                        `uvm_error("INITFC1_STATE", $sformatf("Received unexpected FC1 DLLP POSTED, count: %0d", counter))
                    end
                    else
                    begin
                        counter=0;
                        `uvm_error("INITFC1_STATE", $sformatf("Received unexpected packet of type : %s, resetting counter, count: %0d", dllp_item_rx.dllp_type.name, counter))
                    end
                end
                    
            end
         end //end of forever loop
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