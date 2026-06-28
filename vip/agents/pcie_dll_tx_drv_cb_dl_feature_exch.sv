class pcie_dll_tx_drv_cb_dl_feature_exch extends pcie_dll_tx_drv_cb_base;
  `uvm_object_utils(pcie_dll_tx_drv_cb_dl_feature_exch)

  static int s_object_number = 0;
  int a_object_number;
  
  // Shared state across both objects
  static logic [1:0] state = 2'bxx; 
  // Tracks which of the 4 combinations we have seen
  static bit [3:0] seen_combinations = 4'b0000;

  function new(string name = "pcie_dll_tx_drv_cb_dl_feature_exch");
    super.new(name);
    a_object_number = s_object_number; 
    s_object_number++;
  endfunction

  virtual task pre_transmit(pcie_dll_dllp_seq_item req = null, bit drop = 1'b0);
    if (req == null) return;

    // 1. Update the bit corresponding to THIS object instance
    state[a_object_number] = req.dllp[0];
    //$display(req.dllp[0]);

    // 2. Only check combinations if both bits are valid (not X)
    if (state[0] !== 1'bx && state[1] !== 1'bx) begin
      
      // Mark this combination as seen
      seen_combinations[state] = 1'b1;

      // 3. Logic based on the current 2-bit state
      case (state)
        2'b00: `uvm_info("CB_LOGIC", "Detected State 00", UVM_LOW)
        2'b01: `uvm_info("CB_LOGIC", "Detected State 01", UVM_LOW)
        2'b10: `uvm_info("CB_LOGIC", "Detected State 10", UVM_LOW)
        2'b11: `uvm_info("CB_LOGIC", "Detected State 11", UVM_LOW)
        default: `uvm_error("CB_LOGIC", "Invalid state detected")
      endcase
      
      // 4. Check if all are done
      if (seen_combinations == 4'b1111) begin
        //`uvm_info("CB_LOGIC", "DONE: All 4 combinations have been exercised!", UVM_LOW)
      end

      state = 2'bxx;
      
    end else begin
      //`uvm_info("CB_LOGIC", $sformatf("Waiting for other object. Current state: %b", state), UVM_MEDIUM)
    end

  endtask
endclass