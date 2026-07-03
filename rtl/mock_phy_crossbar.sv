module mock_phy_crossbar #(
    parameter NBYTES = 64,
    parameter bit [2:0] PL_LNK_CFG     = 3'b010,
    parameter bit [2:0] PL_SPEEDMODE   = 3'b101,
    parameter bit       PL_LNK_UP      = 1'b1,
    parameter bit       PL_INBAND_PRES = 1'b1,
    parameter bit       PL_ERROR       = 1'b0,
    parameter bit       PL_CERROR      = 1'b0,
    parameter bit [NBYTES-1:0] PL_TLPEDB = {NBYTES{1'b0}}
)(
    pcie_lpif_if intf_A, // Connects to Root Complex VIP
    pcie_lpif_if intf_B  // Connects to Endpoint VIP
);


    // 1. The Data & Framing Crossbar
    // Route A's Transmit to B's Receive
    assign intf_B.pl_data     = intf_A.lp_data;
    assign intf_B.pl_valid    = intf_A.lp_valid;
    assign intf_B.pl_tlpstart = intf_A.lp_tlpstart;
    assign intf_B.pl_tlpend   = intf_A.lp_tlpend;
    assign intf_B.pl_dlpstart = intf_A.lp_dlpstart;
    assign intf_B.pl_dlpend   = intf_A.lp_dlpend;
    assign intf_B.pl_tlpedb   = PL_TLPEDB;


    // Route B's Transmit to A's Receive
    assign intf_A.pl_data     = intf_B.lp_data;
    assign intf_A.pl_valid    = intf_B.lp_valid;
    assign intf_A.pl_tlpstart = intf_B.lp_tlpstart;
    assign intf_A.pl_tlpend   = intf_B.lp_tlpend;
    assign intf_A.pl_dlpstart = intf_B.lp_dlpstart;
    assign intf_A.pl_dlpend   = intf_B.lp_dlpend;
    assign intf_A.pl_tlpedb   = PL_TLPEDB;

    // Flow Control Handshake Crossover
    assign intf_B.pl_trdy = intf_A.lp_irdy;
    assign intf_A.pl_trdy = intf_B.lp_irdy;


    // 2. State Machine Handshake Bypass

    // Instantly loop requests back as status
    assign intf_A.pl_state_sts = intf_A.lp_state_req;
    assign intf_B.pl_state_sts = intf_B.lp_state_req;
    assign intf_B.pl_lnk_up = intf_A.pl_lnk_up ;

    // 3. LPIF Tie-Offs

    always_comb begin
        // Force Link status to UP for both sides
        // intf_A.pl_lnk_up = intf_B.pl_lnk_up ;
        // intf_B.pl_lnk_up = PL_LNK_UP;

        // In-band presence detected
        intf_A.pl_inband_pres = PL_INBAND_PRES;
        intf_B.pl_inband_pres = PL_INBAND_PRES;

        // Configuration: 010b = x16 link width
        intf_A.pl_lnk_cfg   = PL_LNK_CFG;
        intf_B.pl_lnk_cfg   = PL_LNK_CFG;
        
        // Speedmode: 101b = 32 GT/s (Gen5 speed)
        intf_A.pl_speedmode = PL_SPEEDMODE;
        intf_B.pl_speedmode = PL_SPEEDMODE;

        // Disable physical/analog error signaling
        intf_A.pl_error  = PL_ERROR;
        intf_B.pl_error  = PL_ERROR;
        intf_A.pl_cerror = PL_CERROR;
        intf_B.pl_cerror = PL_CERROR;
    end
endmodule