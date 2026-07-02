// ---- pcie_dll_init2_seq ----

class pcie_dll_init2_seq extends pcie_dll_base_seq;

  // ---- UVM Factory Registration ----
  `uvm_object_utils(pcie_dll_init2_seq)

  // ---- Sequence Configuration & State Variables ----
  pcie_dll_env_cfg   cfg;

  // number of iterations
  rand int unsigned req_count;


  // ---- Constructor ----
  function new (string name = "pcie_dll_init2_seq");
    super.new(name);
  endfunction

  // ---- Main Body Task ----
  virtual task body();
    pcie_dll_dllp_seq_item init2_transaction;

    `uvm_info("SEQ", "Starting InitFC2 Phased Traffic Generation...", UVM_LOW)

    // Get config from uvm_config_db using sequencer context
    if (!uvm_config_db#(pcie_dll_env_cfg)::get(m_sequencer, "", "cfg", cfg)) begin
      `uvm_fatal("SEQ", "Failed to get pcie_dll_env_cfg from config_db")
    end

    // Randomize req_count
    if (!this.randomize() with { 
          req_count   == cfg.req_count;
        }) begin
      `uvm_fatal("SEQ", "Sequence Randomization Failed!")
    end


    repeat (req_count) begin
      // ---- Phase 1: INITFC2_P Traffic ----
      init2_transaction = pcie_dll_dllp_seq_item::type_id::create("init2_transaction"); 

      start_item(init2_transaction);

      if (!init2_transaction.randomize() with { 
            current_state == DL_INIT_FC2;

            if (!(corrupted_initfc)) { // error free
              dllp_type == DLLP_INITFC2_P;
            }
            else { // error injection enabled
            dllp_type dist { 
              DLLP_INITFC2_P   := corrupted_initfc_weight*2, 
              DLLP_INITFC2_NP  := corrupted_initfc_weight*4, 
              DLLP_INITFC2_CPL := corrupted_initfc_weight*4,

              DLLP_INITFC1_P   := corrupted_initfc_weight/2, 
              DLLP_INITFC1_NP  := corrupted_initfc_weight/2, 
              DLLP_INITFC1_CPL := corrupted_initfc_weight/2
            }; 
          }
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC2-P Phase: Item Randomization Failed!")
      end

      finish_item(init2_transaction);


      // ---- Phase 2: NP-Heavy Traffic ----
      init2_transaction = pcie_dll_dllp_seq_item::type_id::create("init2_transaction");

      start_item(init2_transaction);

      if (!init2_transaction.randomize() with { 
            current_state == DL_INIT_FC2; 
            
            if (!(corrupted_initfc)) { // error free
              dllp_type == DLLP_INITFC2_NP;
            }
            else { // error injection enabled
              dllp_type dist { 
                DLLP_INITFC2_P   := corrupted_initfc_weight*4, 
                DLLP_INITFC2_NP  := corrupted_initfc_weight*2, 
                DLLP_INITFC2_CPL := corrupted_initfc_weight*4,

                DLLP_INITFC1_P   := corrupted_initfc_weight/2, 
                DLLP_INITFC1_NP  := corrupted_initfc_weight/2, 
                DLLP_INITFC1_CPL := corrupted_initfc_weight/2
              };
            }
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC2-NP Phase: Item Randomization Failed!")
      end

      finish_item(init2_transaction);

      // ---- Phase 3: CPL-Heavy Traffic ----
      init2_transaction = pcie_dll_dllp_seq_item::type_id::create("init2_transaction");

      start_item(init2_transaction);

      if (!init2_transaction.randomize() with { 
            current_state == DL_INIT_FC2; 
            
            if (!(corrupted_initfc)) { // error free
              dllp_type == DLLP_INITFC2_CPL;
            }
            else { // error injection enabled
              dllp_type dist { 
                DLLP_INITFC2_P   := corrupted_initfc_weight*4, 
                DLLP_INITFC2_NP  := corrupted_initfc_weight*4, 
                DLLP_INITFC2_CPL := corrupted_initfc_weight*2,

                DLLP_INITFC1_P   := corrupted_initfc_weight/2, 
                DLLP_INITFC1_NP  := corrupted_initfc_weight/2, 
                DLLP_INITFC1_CPL := corrupted_initfc_weight/2
              };
            }
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC2-CPL Phase: Item Randomization Failed!")
      end

      finish_item(init2_transaction);
    end

    `uvm_info("SEQ", "InitFC2 Generation Complete.", UVM_LOW)

  endtask

endclass : pcie_dll_init2_seq
