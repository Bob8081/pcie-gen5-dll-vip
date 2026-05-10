// ---- pcie_dll_feature_seq ----
// Generates Feature Request Traffic for the PCIe Link.
// Used to stress test the Feature Exchange state machine by 
// sending multiple consecutive DLLP_FEATURE_REQ packets.

class pcie_dll_feature_seq extends pcie_dll_base_seq;

  // ---- UVM Factory Registration ----
  `uvm_object_utils(pcie_dll_feature_seq)

  // ---- Sequence signals ----
  // Number of Feature Request packets to generate (Default is 5000)
  rand int unsigned   req_count;
  rand bit [22:0]     seq_feature_support;
  rand bit            seq_feature_ack;

  // ---- Constructor ----
  function new (string name = "pcie_dll_feature_seq");
    super.new(name);
  endfunction

  // ---- Main Body Task ----
  virtual task body();
    pcie_dll_dllp_seq_item feature_transaction;

    `uvm_info("SEQ", $sformatf("Starting Feature Request Traffic (%0d packets)...", req_count), UVM_LOW)

    // Randomize sequence-level variables (Phase sizes and Constant Credits)
    if (!this.randomize() with { 
          req_count           inside {[1:5000]};
          seq_feature_support inside {[0:1]};
        }) begin
      `uvm_fatal("SEQ", "Sequence Randomization Failed!")
    end

    // ---- Traffic Generation Loop ----
    repeat (req_count) begin
      feature_transaction = pcie_dll_dllp_seq_item::type_id::create("feature_transaction");
      
      start_item(feature_transaction);

      // Randomize the item and constrain the state to trigger FEATURE_REQ
      if (!feature_transaction.randomize() with { 
            current_state == DL_FEATURE_EXCH;
            
            // Keep payload constant across all packets
            feature_support    == seq_feature_support;
            feature_ack        == seq_feature_ack;
          }) begin
        `uvm_fatal("SEQ_ITEM", "Feature Request Randomization Failed!")
      end

      finish_item(feature_transaction);
    end

    `uvm_info("SEQ", "Feature Request Traffic Complete.", UVM_LOW)

  endtask

endclass : pcie_dll_feature_seq