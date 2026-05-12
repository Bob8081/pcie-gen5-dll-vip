
class pcie_dll_tx_drv_cb_invalid_dllp extends pcie_dll_tx_drv_cb_base;
  
  `uvm_object_utils(pcie_dll_tx_drv_cb_invalid_dllp)

  bit state_satisfied[4] = '{0, 0, 0, 0};

  function new(string name = "pcie_dll_tx_drv_cb_invalid_dllp");
    super.new(name);
  endfunction

  virtual task pre_transmit(pcie_dll_dllp_seq_item req = null, bit drop = 1'b0);
  
    bit trigger = 0;
    int roll;

    // Phase 1: High Priority (20% chance)
    if (!state_satisfied[req.current_state]) begin
        roll = $urandom_range(1, 4); // 1 out of 5 = 20%
        if (roll == 1) begin
            trigger = 1;
            state_satisfied[req.current_state] = 1; // Mark as done with high priority
            $display("State %0d executed.", req.current_state);
            $display("MMMMMMMMMMMMMMMMMMMMMMMM");
        end
    end 

    // Phase 2: Low Priority (0.01% chance)
    else begin
        roll = $urandom_range(1, 500); // 1 out of 10,000
        if (roll == 1) begin
            trigger = 1;
            $display("MMMMMMMMMMMMMMMMMMMM");
            $display("State %0d executed again.", req.current_state);
        end
    end

    // Apply the change to the least 8 bits
    if (trigger) begin
        req.dllp[7:0] = 8'b0000_0000;
    end

  
  endtask
endclass
