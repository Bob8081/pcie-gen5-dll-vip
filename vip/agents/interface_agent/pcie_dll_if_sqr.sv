class pcie_dll_if_sqr extends uvm_sequencer #(pcie_dll_if_seq_item);

    `uvm_component_utils(pcie_dll_if_sqr)

    function new(string name = "pcie_dll_if_sqr", uvm_component parent);
        super.new(name, parent);
    endfunction
    
endclass : pcie_dll_if_sqr