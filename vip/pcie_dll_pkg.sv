package pcie_dll_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Protocol enums and shared typedefs
  typedef enum int unsigned {
    PCIE_LINK_X1  = 1,
    PCIE_LINK_X2  = 2,
    PCIE_LINK_X4  = 4,
    PCIE_LINK_X8  = 8,
    PCIE_LINK_X16 = 16
  } pcie_link_width_e;

  typedef enum int unsigned {
    PCIE_GEN1 = 1,
    PCIE_GEN2 = 2,
    PCIE_GEN3 = 3,
    PCIE_GEN4 = 4,
    PCIE_GEN5 = 5
  } pcie_speed_mode_e;

  // typedef enum int unsigned {
  //   TLP_MRD,
  //   TLP_MWR,
  //   TLP_CPLD,
  //   TLP_MSG,
  //   TLP_OTHER
  // } pcie_tlp_type_e;

  typedef enum bit {
    ROLE_RC = 1'b0,
    ROLE_EP = 1'b1
  } pcie_dll_role_e;

  typedef enum bit [7:0] {
    DLLP_ACK           = 8'h00,  // 0000 0000
    DLLP_NAK           = 8'h10,  // 0001 0000
    DLLP_FEATURE_REQ   = 8'h02,  // 0000 0010
    DLLP_INITFC1_P     = 8'h40,  // 0100 0000 (VC0)
    DLLP_INITFC1_NP    = 8'h50,  // 0101 0000 (VC0)
    DLLP_INITFC1_CPL   = 8'h60,  // 0110 0000 (VC0)
    DLLP_INITFC2_P     = 8'hC0,  // 1100 0000 (VC0)
    DLLP_INITFC2_NP    = 8'hD0,  // 1101 0000 (VC0)
    DLLP_INITFC2_CPL   = 8'hE0,  // 1110 0000 (VC0)
    DLLP_UPDATEFC_P    = 8'h80,  // 1000 0000 (VC0)
    DLLP_UPDATEFC_NP   = 8'h90,  // 1001 0000 (VC0)
    DLLP_UPDATEFC_CPL  = 8'hA0,  // 1010 0000 (VC0)
    DLLP_PWR_MGMT      = 8'h24   // 0010 0100
  } pcie_dllp_type_e;

  typedef enum bit [2:0] {
    DL_INACTIVE        = 3'b000,  // link not yet up; no DLLP traffic permitted
    DL_FEATURE_EXCH    = 3'b001,  // DL Feature Exchange handshake
    DL_INIT_FC1        = 3'b010,  // advertising initial credits (InitFC1 round)
    DL_INIT_FC2        = 3'b011,  // confirming received credits (InitFC2 round)
    DL_ACTIVE          = 3'b100   // link fully active; all DLL traffic permitted
  } pcie_dlcmsm_state_e;


  typedef enum bit [2:0] {
    SENT_TLP        = 3'b000,
    INVALID_DLLP    = 3'b001,
    WRONG_CRC       = 3'b010,
    INVALID_VC      = 3'b011,
    INVALID_CREDITS = 3'b100,
    ERROR_FREE      = 3'b101
  } pcie_dllp_error_e;


  //enum just for credits (only three types)
  typedef enum {
    FC_POSTED = 0,
    FC_NON_POSTED = 1,
    FC_CPL = 2
  } pcie_fc_type_e;

  //credits struct 
  typedef struct {
    pcie_fc_type_e fc_type;

    int unsigned hdr_limit;
    int unsigned data_limit;
    bit [1:0] hdr_scale;
    bit [1:0] data_scale;

    //for saving the absolute values for flow control equations
    int unsigned absolute_hdr_limit;
    int unsigned absolute_data_limit;

    bit [2:0] vc_id = 3'b0; //currently only equals 0

  } pcie_fc_credits_values_s;


  // Included class files

  `include "env/pcie_dll_env_cfg.sv"
  `include "env/pcie_dll_dynamic_cfg.sv"
  `include "helpers/crc16_generator.sv"

  `include "transactions/pcie_dll_base_seq_item.sv"
  `include "transactions/pcie_dll_dllp_seq_item.sv"
  `include "transactions/pcie_dll_tlp_seq_item.sv"
  `include "sequences/pcie_dll_base_seq.sv"
  `include "sequences/pcie_dll_feature_seq.sv"
  `include "sequences/pcie_dll_init1_seq.sv"
  `include "sequences/pcie_dll_init2_seq.sv"
  `include "sequences/pcie_dll_tlp_seq.sv"
  `include "sequences/send_single_packet.sv"

  `include "agents/pcie_dll_tx_drv_cb_base.sv"
  `include "agents/pcie_dll_tx_drv_cb_macro.svh"
  `include "agents/pcie_dll_tx_drv_cb_crc.sv"
  `include "agents/pcie_dll_tx_drv_cb_invalid_dllp.sv"
  `include "agents/pcie_dll_tx_drv_cb_vc.sv"
  //`include "agents/pcie_dll_tx_drv_cb_dl_feature_exch.sv"
  `include "agents/pcie_dll_tx_drv.sv"

  `include "agents/pcie_dll_tx_mon.sv"
  `include "agents/pcie_dll_rx_mon.sv"
  `include "agents/pcie_dll_seqr.sv"

  `include "agents/pcie_dll_base_state.sv"

  `include "agents/pcie_dll_state_mgr.sv"

  `include "agents/pcie_dll_active_state.sv"
  `include "agents/pcie_dll_inactive_state.sv"
  `include "agents/pcie_dll_feature_state.sv"
  `include "agents/pcie_dll_initfc1_state.sv"
  `include "agents/pcie_dll_initfc2_state.sv"



  //`include "scoreboards/common_checks.sv"
  //`include "scoreboards/pcie_dll_scoreboard.sv"
  `include "agents/pcie_dll_agent.sv"
  `include "coverage/pcie_dll_coverage.sv"
  `include "env/pcie_dll_env.sv"

  

  `include "tests/test_base.sv"
  `include "tests/test_dlcmsm_fc_init.sv"

endpackage : pcie_dll_pkg
