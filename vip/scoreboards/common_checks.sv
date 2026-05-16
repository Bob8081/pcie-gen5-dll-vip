class pcie_dll_common_checks extends uvm_subscriber #(pcie_dll_base_seq_item);
  
  // registeration 
  `uvm_object_utils(pcie_dll_common_checks)


  
  // ---- Main Body Task ----
  virtual task body();
    pcie_dll_dllp_seq_item init1_transaction;

    `uvm_info("SEQ", "Starting InitFC1 Phased Traffic Generation...", UVM_LOW)


  // constructor
  function new(string name = "pcie_dll_common_checks", uvm_component parent = null);
    super.new(name,parent);
  endfunction




endclass : pcie_dll_common_checks
