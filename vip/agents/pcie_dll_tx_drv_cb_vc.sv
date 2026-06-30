
class pcie_dll_tx_drv_cb_vc extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_vc)

  function new(string name = "pcie_dll_tx_drv_cb_vc");
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
        roll = $urandom_range(1, 2); // 25%
        //roll = 1;
        if (roll == 1) begin
            trigger = 1'b1;
        end

      end

    if (trigger) begin
        dllp.dllp = {pcie_dll_pkg::crc16_generator::calculate_dllp_crc({dllp.dllp[31:3] ,3'b111}), dllp.dllp[31:3] ,3'b111};
        return 1'b1;

    end

  endfunction
endclass
