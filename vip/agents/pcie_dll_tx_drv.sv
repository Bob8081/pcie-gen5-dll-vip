
class pcie_dll_tx_drv extends uvm_driver #(pcie_dll_base_seq_item);

    //Declaration
    pcie_dll_role_e    role;
    pcie_dll_env_cfg   cfg;
    virtual pcie_lpif_if vif;
    pcie_dll_dllp_seq_item dllp_txn;
    pcie_dll_tlp_seq_item  tlp_txn;
    bit txn_type;

    `uvm_component_utils(pcie_dll_tx_drv)

    //construction
    function new(string name = "pcie_dll_tx_drv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    //build
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!pcie_dll_env_cfg::get_cfg(this, "", cfg)) begin
            `uvm_fatal("NOCFG", "pcie_dll_tx_drv: no cfg found in config_db")
        end
    endfunction

    //connection
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        // Initialize all driven signals to idle via clocking block
        vif.cb_drv.lp_irdy     <= 1'b0;
        vif.cb_drv.lp_valid    <= '0;
        vif.cb_drv.lp_dlpstart <= '0;
        vif.cb_drv.lp_dlpend   <= '0;
        vif.cb_drv.lp_tlpstart <= '0;
        vif.cb_drv.lp_tlpend   <= '0;
        vif.cb_drv.lp_data     <= '0;

        forever begin
            @(vif.cb_drv); // synchronize to clocking block edge
            if (vif.rst_n) begin
                seq_item_port.get_next_item(req);

                if ($cast(dllp_txn, req)) begin
                    `uvm_info("CAST", "Successfully cast to DLLP", UVM_HIGH)
                    txn_type = 1;
                end
                else if ($cast(tlp_txn, req)) begin
                    `uvm_info("CAST", "Successfully cast to TLP", UVM_HIGH)
                    txn_type = 0;
                end
                else begin
                    `uvm_fatal("CAST_FAIL", "Fatal Error: req is neither DLLP nor TLP!")
                end

                if (txn_type == 1) begin
                    vif.cb_drv.lp_irdy    <= 1'b1;
                    // Zero-pad the DLLP to the full lp_data bus width implicitly
                    vif.cb_drv.lp_data    <= dllp_txn.dllp;
                    // Mark only the 6 DLLP bytes as valid
                    vif.cb_drv.lp_valid   <= 6'b111_111;
                    vif.cb_drv.lp_dlpstart <= '0;    // DLLP starts at byte 0
                    vif.cb_drv.lp_dlpend  <= 'd5;   // DLLP ends at byte 6
                end

                else begin
                
                    //TODO : add the TLP path for next stage
                    vif.cb_drv.lp_irdy    <= 1'b1;
                    // put the TLP data on the interface
                    vif.cb_drv.lp_data    <= tlp_txn.tlp;
                    // Mark 16 byte for TLP
                    vif.cb_drv.lp_valid   <= 16'b1111_1111_1111_1111;
                    vif.cb_drv.lp_tlpstart <= '0;    // TLP starts at byte 0
                    vif.cb_drv.lp_tlpend  <= 'd15;   // TLP ends at byte 15
                
                end

                // //reset interface signals
                // vif.cb_drv.lp_irdy     <= 1'b0;
                // vif.cb_drv.lp_valid    <= '0;
                // vif.cb_drv.lp_dlpstart <= '0;
                // vif.cb_drv.lp_dlpend   <= '0;
                // vif.cb_drv.lp_tlpstart <= '0;
                // vif.cb_drv.lp_tlpend   <= '0;
                // vif.cb_drv.lp_data     <= '0;

                seq_item_port.item_done();
                
            end
        end
    endtask

endclass : pcie_dll_tx_drv
