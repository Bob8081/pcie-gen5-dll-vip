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
            `uvm_fatal("NOCONFIG", "pcie_dll_if_drv: virtual interface not found in config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        vif.pl_lnk_up = 1'b1; //initially set the link to be up, the test can control it later by sending requests to the driver
        forever 
        begin

            seq_item_port.get_next_item(req);
            @(vif.cb_drv);
            if (req.drop_link)
            begin
            `uvm_info("IF_DRV", "Dropping the link for a few cycles to simulate a link flap", UVM_LOW)
            vif.cb_drv.pl_lnk_up <= 1'b0;
            repeat(req.cycles_num) @(vif.cb_drv);
            `uvm_info("IF_DRV", "Restoring the link", UVM_LOW)
            vif.cb_drv.pl_lnk_up <= 1'b1;
            end
            seq_item_port.item_done();
            
        end
    endtask

endclass