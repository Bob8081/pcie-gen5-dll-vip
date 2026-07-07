class pcie_dll_if_drv extends uvm_driver #(pcie_dll_if_seq_item);
   
    virtual pcie_lpif_if vif;
    pcie_dll_if_seq_item if_seq;

    `uvm_component_utils(pcie_dll_if_drv)

    function new(string name = "pcie_dll_if_drv", uvm_component parent);
        super.new(name, parent);
    endfunction

    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pcie_lpif_if)::get(this, "", "lnk_vif", vif)) begin
            `uvm_fatal("NOCFG", "pcie_dll_if_drv: virtual interface not found in config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        vif.pl_lnk_up <= 1'b0; //initialize the linkup signal to 0
        wait(vif.rst_n == 1'b1); //wait for the reset then set the linkup signal
        vif.pl_lnk_up <= 1'b1;
        forever 
        begin

            seq_item_port.get_next_item(req);
            @(vif.cb_drv);
            if (req.drop_link)
            begin
            `uvm_info("IF_DRV", "Dropping the link for a few cycles to simulate a link flap", UVM_HIGH)
            vif.cb_drv.pl_lnk_up <= 1'b0;
            repeat(req.cycles_num) @(vif.cb_drv);
            `uvm_info("IF_DRV", "Restoring the link", UVM_HIGH)
            vif.cb_drv.pl_lnk_up <= 1'b1;
            end
            seq_item_port.item_done();
            
        end
    endtask

endclass