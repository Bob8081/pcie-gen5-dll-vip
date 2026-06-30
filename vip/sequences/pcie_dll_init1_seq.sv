// ---- pcie_dll_init1_seq ----

class pcie_dll_init1_seq extends pcie_dll_base_seq;

  // ---- UVM Factory Registration ----
  `uvm_object_utils(pcie_dll_init1_seq)

  pcie_dll_env_cfg   cfg;

  // ---- Sequence Configuration & State Variables ----
  // number of iterations
  rand int unsigned req_count;


  // ---- Constructor ----
  function new (string name = "pcie_dll_init1_seq");
    super.new(name);
  endfunction

  // ---- Main Body Task ----
  virtual task body();
    pcie_dll_dllp_seq_item init1_transaction;

    `uvm_info("SEQ", "Starting InitFC1 Phased Traffic Generation...", UVM_LOW)

    // Get config from uvm_config_db using sequencer context
    if (!uvm_config_db#(pcie_dll_env_cfg)::get(m_sequencer, "", "cfg", cfg)) begin
      `uvm_fatal("SEQ", "Failed to get pcie_dll_env_cfg from config_db")
    end


    // Randomize req_count
    if (!this.randomize() with { 
          req_count == cfg.req_count;
        }) begin
      `uvm_fatal("SEQ", "Sequence Randomization Failed!")
    end

    repeat (req_count) begin
      // ---- Phase 1: INITFC1_P Traffic  ----
      init1_transaction = pcie_dll_dllp_seq_item::type_id::create("init1_transaction"); 

      start_item(init1_transaction);

      if (!init1_transaction.randomize() with { 
            current_state == DL_INIT_FC1;
            
            if (!(corrupted_initfc)) { // error free
              dllp_type == DLLP_INITFC1_P;
            }
            else { // error injection enabled
              dllp_type dist { 
              DLLP_INITFC1_P   := 20, 
              DLLP_INITFC1_NP  := 40, 
              DLLP_INITFC1_CPL := 40,
              
              DLLP_INITFC2_P   := 20
            }; 
          }
           } 
      ) begin
        `uvm_fatal("SEQ_ITEM", "INITFC1-P Phase: Item Randomization Failed!")
      end

      finish_item(init1_transaction);


      init1_transaction = pcie_dll_dllp_seq_item::type_id::create("init1_transaction");

      start_item(init1_transaction);

      if (!init1_transaction.randomize() with { 
            current_state == DL_INIT_FC1;
            
            if (!(corrupted_initfc)) { // error free
              dllp_type == DLLP_INITFC1_NP;
            }
            else  {// error injection enabled
            dllp_type dist { 
              DLLP_INITFC1_P   := 40, 
              DLLP_INITFC1_NP  := 20, 
              DLLP_INITFC1_CPL := 40,
              
              DLLP_INITFC2_P   := 20
            };
          }
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC1-NP Phase: Item Randomization Failed!")
      end

      finish_item(init1_transaction);


      init1_transaction = pcie_dll_dllp_seq_item::type_id::create("init1_transaction");

      start_item(init1_transaction);

      if (!init1_transaction.randomize() with { 
            current_state == DL_INIT_FC1;
            
            if (!(corrupted_initfc)) { // error free
              dllp_type == DLLP_INITFC1_CPL;
            }
            else {// error injection enabled
            dllp_type dist { 
              DLLP_INITFC1_P   := 40, 
              DLLP_INITFC1_NP  := 40, 
              DLLP_INITFC1_CPL := 20
              
            };
          }
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC1-CPL Phase: Item Randomization Failed!")
      end

      finish_item(init1_transaction);
    end

    `uvm_info("SEQ", "InitFC1 Generation Complete.", UVM_LOW)

  endtask

endclass : pcie_dll_init1_seq
