
class pcie_dll_rx_mon extends uvm_monitor;

  uvm_analysis_port #(pcie_dll_base_seq_item) mon_rx_ap;
  
  pcie_dll_role_e  role;
  pcie_dll_env_cfg cfg;

  virtual pcie_lpif_if vif;

  pcie_dll_base_seq_item base_seq;
  pcie_dll_tlp_seq_item  tlp_item;
  pcie_dll_dllp_seq_item dllp_item; 

  `uvm_component_utils(pcie_dll_rx_mon)

  function new(string name = "pcie_dll_rx_mon", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_rx_ap = new("mon_rx_ap", this);
    if (!pcie_dll_env_cfg::get_cfg(this, "", cfg)) begin
      `uvm_fatal("NOCFG", "pcie_dll_rx_mon: no cfg found in config_db")
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin

      //TODO : callbacks to be called to simulate errors
      @(vif.cb_mon_rx);
      if (vif.rst_n && vif.pl_lnk_up) begin
        // A DLLP is present when:
        //   - exactly the 6 DLLP bytes are valid on pl_valid (upper bytes = 0)
        //   - dlpstart < dlpend framing flags indicate a DLLP frame
        //TODO : make it more dynamic

        if ((!(vif.cb_mon_rx.pl_dlpstart >= vif.cb_mon_rx.pl_dlpend)) &
             (vif.cb_mon_rx.pl_valid == 6'b111_111)) begin //TODO : add more link checks
          dllp_item = pcie_dll_dllp_seq_item::type_id::create("dllp_item");
          // DLLP is always packed into the lowest 48 bits of pl_data
          dllp_item.unpack(vif.cb_mon_rx.pl_data[47:0]);
          dllp_item.current_state = pcie_dll_pkg::partner_state_expector::get_rx_current_state(dllp_item.dllp_type, this.get_full_name());
          mon_rx_ap.write(dllp_item);
          `uvm_info("RX_MON", $sformatf("Observed RX DLLP: %h", dllp_item.dllp), UVM_LOW)
        end
        else if ((!(vif.cb_mon_rx.pl_tlpstart >= vif.cb_mon_rx.pl_tlpend)) &
             (vif.cb_mon_rx.pl_valid == 16'b1111_1111_1111_1111)) 
        begin //TODO : add more link checks
          tlp_item = pcie_dll_tlp_seq_item::type_id::create("tlp_item");
          // DLLP is always packed into the lowest 48 bits of pl_data
          tlp_item.tlp=vif.cb_mon_rx.pl_data[127:0];
          tlp_item.current_state = DL_ACTIVE;
          mon_rx_ap.write(tlp_item);
          `uvm_info("RX_MON", $sformatf("Observed RX TLP: %h", tlp_item.tlp), UVM_LOW)
        end
      end
    end
  endtask 

endclass : pcie_dll_rx_mon
