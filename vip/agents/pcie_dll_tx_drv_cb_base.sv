class pcie_dll_tx_drv_cb_base extends uvm_callback; // the base class
    `uvm_object_utils(pcie_dll_tx_drv_cb_base)

    function new(string name = "pcie_dll_tx_drv_cb_base");
        super.new(name);
    endfunction

    // tasks that would be overriden
    virtual function bit pre_transmit(pcie_dll_base_seq_item req = null, bit drop = 1'b0);
        return 1'b0;
    endfunction

    virtual function bit post_transmit(pcie_dll_base_seq_item req = null);
        return 1'b0;
    endfunction
endclass