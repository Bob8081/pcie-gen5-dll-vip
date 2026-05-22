
class pcie_dll_tx_mon extends uvm_monitor;

  uvm_analysis_port #(pcie_dll_base_seq_item) mon_tx_ap;
  
  pcie_dll_role_e  role;
  pcie_dll_env_cfg cfg;

  virtual pcie_lpif_if vif;

  pcie_dll_base_seq_item base_seq;
  pcie_dll_tlp_seq_item  tlp_item;
  pcie_dll_dllp_seq_item dllp_item; 

  `uvm_component_utils(pcie_dll_tx_mon)

  function new(string name = "pcie_dll_tx_mon", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon_tx_ap = new("mon_tx_ap", this);
    if (!pcie_dll_env_cfg::get_cfg(this, "", cfg)) begin
      `uvm_fatal("NOCFG", "pcie_dll_tx_mon: no cfg found in config_db")
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    forever begin

      //TODO : check for reset with assertions not monitor
      @(vif.cb_mon_tx);
      if (vif.rst_n && vif.pl_lnk_up) begin
        // A DLLP is present when:
        //   - lp_irdy is asserted (DLL ready)
        //   - pl_trdy is asserted (PHY accepted)
        //   - exactly the 6 DLLP bytes are valid (upper bytes = 0)
        //   - dlpstart < dlpend framing flags are set
        //TODO : make the check for existence of dllp more dynamic
        if ((!(vif.cb_mon_tx.lp_dlpstart >= vif.cb_mon_tx.lp_dlpend))             &
             (vif.cb_mon_tx.lp_irdy  == 1'b1)                                       &
             (vif.cb_mon_tx.lp_valid == 6'b111_111)       &
             (vif.cb_mon_tx.pl_trdy  == 1'b1)) 
        begin
          dllp_item = pcie_dll_dllp_seq_item::type_id::create("dllp_item");
          // DLLP is always packed into the lowest 48 bits of lp_data
          dllp_item.unpack(vif.cb_mon_tx.lp_data[47:0]);
          mon_tx_ap.write(dllp_item);
          `uvm_info("MON", $sformatf("Observed TX DLLP: %h", dllp_item.dllp), UVM_LOW)
        end

        else if ((!(vif.cb_mon_tx.lp_tlpstart >= vif.cb_mon_tx.lp_tlpend))             &
             (vif.cb_mon_tx.lp_irdy  == 1'b1)                                       &
             (vif.cb_mon_tx.lp_valid == 16'b1111_1111_1111_1111)       &
             (vif.cb_mon_tx.pl_trdy  == 1'b1)) 
        begin
          tlp_item = pcie_dll_tlp_seq_item::type_id::create("tlp_item");
          // DLLP is always packed into the lowest 48 bits of lp_data
          tlp_item.tlp=vif.cb_mon_tx.lp_data[127:0];
          mon_tx_ap.write(tlp_item);
          `uvm_info("MON", $sformatf("Observed TX TLP: %h", tlp_item.tlp), UVM_LOW)
        end
      end
    end
  endtask 

endclass : pcie_dll_tx_mon
