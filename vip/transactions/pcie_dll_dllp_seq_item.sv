// ---- pcie_dll_dllp_seq_item ----
// Represents a well-formed Data Link Layer Packet (DLLP) for PCIe.
// Handles the generation of InitFC and Feature Request payloads,
// along with automatic CRC calculation post-randomization.

class pcie_dll_dllp_seq_item extends pcie_dll_base_seq_item;

  // TODO: update constraints to meet 100% coverage 

  // ---- Control Signals ----
  // Drives the randomization of dllp_type based on the current Link state
  rand pcie_dlcmsm_state_e  current_state;  

  // ---- Core DLLP Fields ----
  rand pcie_dllp_type_e     dllp_type;      // INITFC1_P, FEATURE_REQ
  bit  [15:0]               crc;            // Calculated automatically in post_randomize
  bit  [23:0]               dllp_payload;   // Constructed based on dllp_type

  // ---- InitFC Specific Fields (Credits) ----
  rand bit [1:0]            hdr_scale;
  rand bit [1:0]            data_scale;
  rand bit [7:0]            hdr_FC;
  rand bit [11:0]           data_FC;

  // ---- Feature Request Specific Fields ----
  rand bit [22:0]           feature_support;
  rand bit                  feature_ack;

  // ---- Final Assembled Packet & Timing ----
  bit  [47:0]               dllp;           // The complete 6-byte DLLP sent to the driver
  rand int unsigned         delay;          // Delay in cycles before sending the packet

  // ---- UVM Factory Registration & Field Macros ----
  `uvm_object_utils_begin(pcie_dll_dllp_seq_item)
    `uvm_field_enum(pcie_dlcmsm_state_e, current_state,  UVM_ALL_ON)
    `uvm_field_enum(pcie_dllp_type_e, dllp_type,         UVM_ALL_ON)
    `uvm_field_int (crc,                                 UVM_ALL_ON)
    `uvm_field_int (dllp_payload,                        UVM_ALL_ON)
    `uvm_field_int (hdr_scale,                           UVM_ALL_ON)
    `uvm_field_int (data_scale,                          UVM_ALL_ON)
    `uvm_field_int (hdr_FC,                              UVM_ALL_ON)
    `uvm_field_int (data_FC,                             UVM_ALL_ON)
    `uvm_field_int (feature_support,                     UVM_ALL_ON)
    `uvm_field_int (feature_ack,                         UVM_ALL_ON)
    `uvm_field_int (dllp,                                UVM_ALL_ON)
    `uvm_field_int (delay,                               UVM_ALL_ON)
  `uvm_object_utils_end

  // ---- Constructor ----
  function new(string name = "pcie_dll_dllp_seq_item");
    super.new(name);
  endfunction

  // ---- Constraints ----

  // Default state is inactive, can be overridden by Sequences
  constraint state_constr { 
    soft current_state inside {DL_INACTIVE};
  }

  // Back-to-back traffic is highly probable, with occasional slight delays
  constraint delay_constr { 
    delay dist {
      0  := 90, 
      10 := 9, 
      20 := 1
    };
  }

  // Ensures the generated DLLP type strictly matches the current Link state
  constraint dllp_type_constr { 
    
    // Feature Exchange State
    if (current_state == DL_FEATURE_EXCH) { 
      dllp_type == DLLP_FEATURE_REQ;
    } 
    
    // InitFC1 State
    else if (current_state == DL_INIT_FC1) { 
      dllp_type inside { 
        DLLP_INITFC1_P, 
        DLLP_INITFC1_NP, 
        DLLP_INITFC1_CPL 
      };
    } 
    
    // InitFC2 State
    else if (current_state == DL_INIT_FC2) { 
      dllp_type inside { 
        DLLP_INITFC2_P, 
        DLLP_INITFC2_NP, 
        DLLP_INITFC2_CPL  
      };
    } 
  }

  // ---- Methods ----

  // post_randomize() — Assembles payload, calculates CRC, and concatenates final 48-bit DLLP
  function void post_randomize();
    bit [31:0] full_data; // Temporary variable to hold Type + Payload for CRC calculation
       
    // Construct the 24-bit Payload based on the randomized type
    if (dllp_type == DLLP_FEATURE_REQ) begin
      dllp_payload = {feature_ack, feature_support};
    end 
    else begin // Applies to both InitFC1 and InitFC2
      dllp_payload = {hdr_scale, hdr_FC, data_scale, data_FC};
    end

    // Calculate the 16-bit CRC
    full_data = {dllp_type, dllp_payload};
    crc       = pcie_dll_pkg::crc16_generator::calculate_dllp_crc(full_data);
      
    // Assemble the final 48-bit DLLP (Type + Payload + CRC)
    dllp      = pack();
  endfunction

  // pack() — serialize the transaction into the 48-bit wire representation.
  // Layout (MSB→LSB): [47:40] dllp_type | [39:16] dllp_payload | [15:0] crc
  // Driver calls this to get the value to place on lp_data[47:0].
  function bit [47:0] pack();
    return {dllp_type, dllp_payload, crc};
  endfunction

  // unpack() — deserialize a raw 48-bit bus word back into all named fields.
  // Monitor calls this after reconstructing the wire word from lp_data/pl_data.
  function void unpack(bit [47:0] raw);
    dllp         = raw;
    dllp_type    = pcie_dllp_type_e'(raw[47:40]);
    dllp_payload = raw[39:16];
    crc          = raw[15:0];

    // Expand payload sub-fields based on decoded type
    if (dllp_type == DLLP_FEATURE_REQ) begin
      feature_ack     = dllp_payload[23];
      feature_support = dllp_payload[22:0];
    end else begin // InitFC1 / InitFC2
      hdr_scale  = dllp_payload[23:22];
      hdr_FC     = dllp_payload[21:14];
      data_scale = dllp_payload[13:12];
      data_FC    = dllp_payload[11:0];
    end
  endfunction

endclass : pcie_dll_dllp_seq_item