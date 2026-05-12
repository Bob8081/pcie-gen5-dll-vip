
class pcie_dll_tx_drv_cb_crc extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_crc)

  function new(string name = "pcie_dll_tx_drv_cb_crc");
    super.new(name);
  endfunction

  virtual task pre_transmit(pcie_dll_dllp_seq_item req = null, bit drop = 1'b0);
    
    bit trigger = 1'b0;
    int roll;

      if (req.enable_errors == 1'b1) begin

        roll = $urandom_range(1, 2); // 50%
        if (roll == 1) begin
            trigger = 1'b1;
        end
      end

    if (trigger) begin
        req.dllp[7:0] = 8'h00;
    end

  endtask
endclass
