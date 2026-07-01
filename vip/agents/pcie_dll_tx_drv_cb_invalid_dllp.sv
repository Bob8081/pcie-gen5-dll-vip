
class pcie_dll_tx_drv_cb_invalid_dllp extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_invalid_dllp)

  function new(string name = "pcie_dll_tx_drv_cb_invalid_dllp");
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
        roll =$urandom_range(1, 3); // 25%
        if (roll == 1) begin
            trigger = 1'b1;
        end
      end

    if (trigger) begin
        dllp.dllp = {pcie_dll_pkg::crc16_generator::calculate_dllp_crc(32'd0), 32'd0}; // Invalid DLLP with type = 0 and payload = 0, CRC = 0xB362
        return 1'b1;
    end

  endfunction
endclass : pcie_dll_tx_drv_cb_invalid_dllp
