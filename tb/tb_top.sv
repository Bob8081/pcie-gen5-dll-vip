`timescale 1ns/1ps

`include "uvm_macros.svh"


// Top-Level Testbench
// Instantiates the LPIF interfaces and Mock PHY Crossbar, then connects them.
module tb_top;

    import uvm_pkg::*;
    import pcie_dll_pkg::*;


    // Parameters
    localparam NBYTES = 64; // Gen5 x16 @ 1 GHz = 64 bytes/cycle
    localparam bit [2:0] LPIF_LNK_CFG     = 3'b010;
    localparam bit [2:0] LPIF_SPEEDMODE   = 3'b101;
    localparam bit       LPIF_LNK_UP      = 1'b1;
    localparam bit       LPIF_INBAND_PRES = 1'b1;


    // Clock & Reset Generation
    logic lclk;
    logic rst_n;

    
    // 1 GHz clock 
    initial lclk = 0;
    always #0.5 lclk = ~lclk;

    // Assert reset for 10 cycles, then deassert
    initial begin
        rst_n = 1'b0;
        repeat(10) @(posedge lclk);
        rst_n = 1'b1;
    end


    // Interface Instantiations
    pcie_lpif_if #(.NBYTES(NBYTES)) rc_if (.lclk(lclk), .rst_n(rst_n)); // Root Complex side
    pcie_lpif_if #(.NBYTES(NBYTES)) ep_if (.lclk(lclk), .rst_n(rst_n)); // Endpoint side

    // DUT: Mock PHY Crossbar
    // Wires the two LPIF interfaces together so Tx of one becomes Rx of other.
    mock_phy_crossbar #(
        .NBYTES(NBYTES),
        .PL_LNK_CFG(LPIF_LNK_CFG),
        .PL_SPEEDMODE(LPIF_SPEEDMODE),
        .PL_LNK_UP(LPIF_LNK_UP),
        .PL_INBAND_PRES(LPIF_INBAND_PRES)
    ) u_crossbar (
        .intf_A (rc_if),
        .intf_B (ep_if)
    );

    // Simulation Body 
    // Publish testbench-level parameters to config_db, then run test.
    initial begin
        //TODO : see how to change Nbytes of the interface to change the speed 
        uvm_config_db#(int)::set(uvm_root::get(), "*", "tb_nbytes", NBYTES);
        uvm_config_db#(pcie_link_width_e)::set(uvm_root::get(), "*", "tb_link_width", PCIE_LINK_X16);
        uvm_config_db#(pcie_speed_mode_e)::set(uvm_root::get(), "*", "tb_speed_mode", PCIE_GEN5);
        uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "rc_vif", rc_if);
        uvm_config_db#(virtual pcie_lpif_if)::set(uvm_root::get(), "*", "ep_vif", ep_if);
        // Run Test
        run_test("pcie_dll_test_base");
    end

endmodule
