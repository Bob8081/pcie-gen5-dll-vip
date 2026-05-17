
class pcie_dll_tx_drv_cb_vc extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_vc)

  function new(string name = "pcie_dll_tx_drv_cb_vc");
    super.new(name);
  endfunction

  virtual function bit pre_transmit(pcie_dll_dllp_seq_item req = null, bit drop = 1'b0);
    
    bit trigger = 1'b0;
    int roll;

    // req.dllp_type.name() != "DLLP_FEATURE_REQ";

      if (req.enable_errors == 1'b1) begin
        roll = $urandom_range(1, 10); // 90%
        if (roll != 1) begin
            trigger = 1'b1;
        end

      end

    if (trigger) begin
        req.dllp[2:0] = 3'b111;
        $display("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv");

    end

  endfunction
endclass
