
class pcie_dll_tx_drv_cb_crc extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_crc)


    // enable_errors


  bit type_satisfied[string] = '{
    "DLLP_FEATURE_REQ" : 0,
    "DLLP_INITFC1_P"   : 0,
    "DLLP_INITFC1_NP"  : 0,
    "DLLP_INITFC1_CPL" : 0,
    "DLLP_INITFC2_P"   : 0,
    "DLLP_INITFC2_NP"  : 0,
    "DLLP_INITFC2_CPL" : 0
  };


  function new(string name = "pcie_dll_tx_drv_cb_crc");
    super.new(name);
  endfunction

  virtual task pre_transmit(pcie_dll_dllp_seq_item req = null, bit drop = 1'b0);
    
    bit trigger = 1'b0;
    int roll;

      //if (req.enable_errors == 1'b1) begin

        roll = $urandom_range(1, 2); // 50%

        if (roll == 1) begin
            trigger = 1'b0;

            $display(req.dllp_type.name());

            type_satisfied[req.dllp_type.name()] = 1; // Mark as done

            $display([CRC ERROR:],"dllp before changing CRC", "%b", req.dllp);

        end

      //end


    // Apply the change to the top 16 bits
    if (trigger) begin
        req.dllp[47:32] = 16'h0000;
    end

  endtask
endclass
