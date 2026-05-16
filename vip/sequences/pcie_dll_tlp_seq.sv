// ---- pcie_dll_tlp_seq ----
// Generates a single Transaction Layer Packet (TLP) sequence item.
// Used for basic directed testing by injecting a fixed dummy 
// 128-bit TLP payload into the design without randomization.

class pcie_dll_tlp_seq extends pcie_dll_base_seq;

  // ---- UVM Factory Registration ----
  `uvm_object_utils(pcie_dll_tlp_seq)

  // ---- Constructor ----
  function new (string name = "pcie_dll_tlp_seq");
    super.new(name);
  endfunction

  // ---- Main Body Task ----
  virtual task body();
    pcie_dll_tlp_seq_item tlp_transaction;

    `uvm_info("SEQ", "Starting Basic TLP Traffic Generation...", UVM_LOW)

    // Create the transaction item via the Factory
    tlp_transaction = pcie_dll_tlp_seq_item::type_id::create("tlp_transaction");

    // Request the Driver
    start_item(tlp_transaction);

    // Assign the fixed dummy payload (Directed Stimulus)
    // Note: Bypassing randomize() is intentional here for specific payload injection
    tlp_transaction.tlp = 128'hDEADBEEF_CAFEBABE_11223344_55667788;

    // Send the item to the Driver
    finish_item(tlp_transaction);

    `uvm_info("SEQ", "Basic TLP Traffic Complete.", UVM_LOW)

  endtask

endclass : pcie_dll_tlp_seq