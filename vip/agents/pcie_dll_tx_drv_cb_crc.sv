
class pcie_dll_tx_drv_cb_crc extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_crc)

  function new(string name = "pcie_dll_tx_drv_cb_crc");
    super.new(name);
  endfunction

  virtual function bit pre_transmit(pcie_dll_base_seq_item req = null, bit drop = 1'b0);
    
    bit trigger = 1'b0;
    int roll;
    pcie_dll_dllp_seq_item dllp;
    if (!$cast(dllp, req)) begin
        `uvm_error("CB_CAST", "pre_transmit: req is not a DLLP seq item")
        return 1'b0;
    end

    if (dllp.enable_errors == 1'b1) begin
        roll = $urandom_range(1, dllp.crc_error_weight); 
        if (roll != 1) begin
            trigger = 1'b1;
        end
      end

      
    // Apply the change to the top 16 bits)
    if (trigger) begin
        dllp.dllp[47:32] = 16'h0000;
        return 1'b1;
    end

  endfunction
endclass
