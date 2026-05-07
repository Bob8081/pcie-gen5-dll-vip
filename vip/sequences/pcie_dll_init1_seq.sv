// ---- pcie_dll_init1_seq ----

class pcie_dll_init1_seq extends pcie_dll_base_seq;

  // ---- UVM Factory Registration ----
  `uvm_object_utils(pcie_dll_init1_seq)

  // ---- Sequence Configuration & State Variables ----
  // number of iterations
  rand int unsigned req_count;

  // Local variables for config-driven credits
  pcie_dll_env_cfg   cfg;
  bit [1:0]          hdr_scale_p;
  bit [7:0]          hdr_fc_p;
  bit [1:0]          data_scale_p;
  bit [11:0]         data_fc_p;
  bit [1:0]          hdr_scale_np;
  bit [7:0]          hdr_fc_np;
  bit [1:0]          data_scale_np;
  bit [11:0]         data_fc_np;
  bit [1:0]          hdr_scale_cpl;
  bit [7:0]          hdr_fc_cpl;
  bit [1:0]          data_scale_cpl;
  bit [11:0]         data_fc_cpl;

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

    // Extract fixed FC credit values from config for each VC
    hdr_scale_p    = cfg.init_fc_hdr_scale_p;
    hdr_fc_p       = cfg.init_fc_hdr_p;
    data_scale_p   = cfg.init_fc_data_scale_p;
    data_fc_p      = cfg.init_fc_data_p;

    hdr_scale_np   = cfg.init_fc_hdr_scale_np;
    hdr_fc_np      = cfg.init_fc_hdr_np;
    data_scale_np  = cfg.init_fc_data_scale_np;
    data_fc_np     = cfg.init_fc_data_np;

    hdr_scale_cpl  = cfg.init_fc_hdr_scale_cpl;
    hdr_fc_cpl     = cfg.init_fc_hdr_cpl;
    data_scale_cpl = cfg.init_fc_data_scale_cpl;
    data_fc_cpl    = cfg.init_fc_data_cpl;

    // Randomize req_count
    if (!this.randomize() with { 
          req_count   inside {[150:200]};
        }) begin
      `uvm_fatal("SEQ", "Sequence Randomization Failed!")
    end

    repeat (req_count) begin
      // ---- Phase 1: P-Heavy Traffic (98% P, 1% NP, 1% CPL) ----
      init1_transaction = pcie_dll_dllp_seq_item::type_id::create("init1_transaction"); 

      start_item(init1_transaction);

      if (!init1_transaction.randomize() with { 
            current_state == DL_INIT_FC1; 

            hdr_scale  == hdr_scale_p;
            data_scale == data_scale_p;
            hdr_FC     == hdr_fc_p;
            data_FC    == data_fc_p;
            
            dllp_type dist { 
              DLLP_INITFC1_P   := 98, 
              DLLP_INITFC1_NP  := 1, 
              DLLP_INITFC1_CPL := 1 
            }; 
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC1-P Phase: Item Randomization Failed!")
      end

      finish_item(init1_transaction);


      // ---- Phase 2: NP-Heavy Traffic (1% P, 98% NP, 1% CPL) ----
      init1_transaction = pcie_dll_dllp_seq_item::type_id::create("init1_transaction");

      start_item(init1_transaction);

      if (!init1_transaction.randomize() with { 
            current_state == DL_INIT_FC1; 

            hdr_scale  == hdr_scale_np;
            data_scale == data_scale_np;
            hdr_FC     == hdr_fc_np;
            data_FC    == data_fc_np;
            
            dllp_type dist { 
              DLLP_INITFC1_P   := 1, 
              DLLP_INITFC1_NP  := 98, 
              DLLP_INITFC1_CPL := 1 
            };
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC1-NP Phase: Item Randomization Failed!")
      end

      finish_item(init1_transaction);

      // ---- Phase 3: CPL-Heavy Traffic (2% P, 2% NP, 96% CPL) ----
      init1_transaction = pcie_dll_dllp_seq_item::type_id::create("init1_transaction");

      start_item(init1_transaction);

      if (!init1_transaction.randomize() with { 
            current_state == DL_INIT_FC1; 

           hdr_scale  == hdr_scale_cpl;
           data_scale == data_scale_cpl;
           hdr_FC     == hdr_fc_cpl;
           data_FC    == data_fc_cpl;
            
            dllp_type dist { 
              DLLP_INITFC1_P   := 1, 
              DLLP_INITFC1_NP  := 1, 
              DLLP_INITFC1_CPL := 98 
            }; 
          }) begin
        `uvm_fatal("SEQ_ITEM", "INITFC1-CPL Phase: Item Randomization Failed!")
      end

      finish_item(init1_transaction);
    end

    `uvm_info("SEQ", "InitFC1 Generation Complete.", UVM_LOW)

  endtask

endclass : pcie_dll_init1_seq
