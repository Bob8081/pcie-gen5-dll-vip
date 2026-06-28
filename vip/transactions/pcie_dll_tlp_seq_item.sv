class pcie_dll_tlp_seq_item extends pcie_dll_base_seq_item;

    rand bit [127:0] tlp;
    rand pcie_dlcmsm_state_e current_state;

    // ---- Registration ----
    `uvm_object_utils_begin (pcie_dll_tlp_seq_item)
    `uvm_field_int (tlp,UVM_ALL_ON)
    `uvm_field_enum (pcie_dlcmsm_state_e, current_state, UVM_ALL_ON)
    `uvm_object_utils_end

    // ---- Constructor ----
    function new (string name= "pcie_dll_tlp_seq_item" );
      super.new(name);
    endfunction

endclass : pcie_dll_tlp_seq_item