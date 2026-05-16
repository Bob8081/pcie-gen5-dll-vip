class pcie_dll_seqr extends uvm_sequencer #(pcie_dll_base_seq_item);

  pcie_dll_role_e role;

  `uvm_component_utils(pcie_dll_seqr)

  function new(string name = "pcie_dll_seqr", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : pcie_dll_seqr
