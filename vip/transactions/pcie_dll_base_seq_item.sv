class pcie_dll_base_seq_item extends uvm_sequence_item;

    // ---- Registration ----
    `uvm_object_utils (pcie_dll_base_seq_item)

    // ---- Constructor ----
    function new (string name= "pcie_dll_base_seq_item");
      super.new (name);
    endfunction

endclass : pcie_dll_base_seq_item