class pcie_dll_state_manager_item extends uvm_object;

    // ---- Fields ----
    pcie_dlcmsm_state_e tx_state;
    pcie_dlcmsm_state_e rx_state;
    unsigned int        counter;

    // ---- UVM Registration ----
    `uvm_object_utils_begin(pcie_dll_state_manager_item)
        `uvm_field_enum(pcie_dlcmsm_state_e, tx_state, UVM_ALL_ON)
        `uvm_field_enum(pcie_dlcmsm_state_e, rx_state, UVM_ALL_ON)
        `uvm_field_int (counter,                       UVM_ALL_ON)
    `uvm_object_utils_end

    // ---- Constructor ----
    function new(string name = "pcie_dll_state_manager_item");
        super.new(name);
    endfunction

endclass : pcie_dll_state_manager_item