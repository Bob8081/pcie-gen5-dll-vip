class pcie_dll_tx_drv_cb_base extends uvm_callback; // the base class
    `uvm_object_utils(pcie_dll_tx_drv_cb_base)

    function new(string name = "pcie_dll_tx_drv_cb_base");
        super.new(name);
    endfunction

    // tasks that would be overriden
    virtual task pre_transmit(pcie_dll_dllp_seq_item req = null, bit drop = 1'b0);  endtask
    virtual task post_transmit(pcie_dll_dllp_seq_item req = null); endtask
endclass