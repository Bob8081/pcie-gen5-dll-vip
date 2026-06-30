class pcie_dll_if_mon extends uvm_monitor;

    virtual pcie_lpif_if vif;
    pcie_dll_if_seq_item if_seq;
    pcie_dll_link_cfg lnk_cfg;

    `uvm_component_utils(pcie_dll_if_mon)

    function new(string name = "pcie_dll_if_mon", uvm_component parent);
        super.new(name, parent);
    endfunction

    
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual pcie_lpif_if)::get(this, "", "lnk_vif", vif)) begin
            `uvm_fatal("NOCFG", "pcie_dll_if_mon: virtual interface not found in config_db")
        end
        if(!uvm_config_db#(pcie_dll_link_cfg)::get(this, "", "lnk_cfg", lnk_cfg))begin
            `uvm_fatal("NOCFG", "pcie_dll_if_mon: pcie_dll_link_cfg not found in config_db")
        end
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        forever 
        begin
            @(vif.pl_lnk_up); //TODO : add more signals to monitor for better checking and coverage
            `uvm_info("LINK_STATUS_CHANGE", $sformatf("Link status changed, new status: %b", vif.pl_lnk_up), UVM_LOW)
            lnk_cfg.pl_up = vif.pl_lnk_up;
            if(lnk_cfg.pl_up) begin
                `uvm_info("LINK_UP", "Link is up!", UVM_LOW)
                lnk_cfg.pl_asserted.trigger();
            end
            else begin
                `uvm_info("LINK_DOWN", "Link is down!", UVM_LOW)
                lnk_cfg.pl_realesed.trigger();
            end
        end
    endtask
endclass : pcie_dll_if_mon
        