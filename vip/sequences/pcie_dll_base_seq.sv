class pcie_dll_base_seq extends uvm_sequence #(pcie_dll_base_seq_item);

  // ---- Registration ----
  `uvm_object_utils(pcie_dll_base_seq)

  // ---- Constructor ----
  function new(string name = "pcie_dll_base_seq");
    super.new(name);
  endfunction

endclass : pcie_dll_base_seq