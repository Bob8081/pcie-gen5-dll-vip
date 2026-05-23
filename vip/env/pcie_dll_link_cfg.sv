class pcie_dll_link_cfg extends uvm_object;

    bit pl_up;
    bit is_in_reset;
    uvm_event pl_asserted;
    uvm_event pl_realesed;
    uvm_event reset_asserted;
    uvm_event reset_released;

    `uvm_object_utils(pcie_dll_link_cfg)

    function new(string name = "pcie_dll_link_cfg");
        super.new(name);
        pl_asserted = new("pl_asserted");
        pl_realesed = new("pl_realesed");
        reset_asserted = new("reset_asserted");
        reset_released = new("reset_released");
    endfunction

endclass : pcie_dll_link_cfg