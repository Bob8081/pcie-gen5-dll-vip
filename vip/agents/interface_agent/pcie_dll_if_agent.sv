class pcie_dll_if_agent extends uvm_component;

    pcie_dll_if_drv if_drv;
    pcie_dll_if_mon if_mon;
    pcie_dll_if_sqr if_sqr;

    `uvm_component_utils(pcie_dll_if_agent)

    function new(string name = "pcie_dll_if_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if_drv = pcie_dll_if_drv::type_id::create("if_drv", this);
        if_mon = pcie_dll_if_mon::type_id::create("if_mon", this);
        if_sqr = pcie_dll_if_sqr::type_id::create("if_sqr", this);
    endfunction
    
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if_drv.seq_item_port.connect(if_sqr.seq_item_export);
    endfunction

endclass : pcie_dll_if_agent