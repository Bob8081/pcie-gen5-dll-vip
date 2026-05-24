interface pcie_lpif_if #(
    parameter NBYTES = 64
)(
    input logic lclk,
    input logic rst_n
);
    //TODO : review the signals and add real simulation for the handshaking signals 

    //TODO  : the linkup signal (designated driver for link shutdown)

    logic [(NBYTES*8)-1:0] lp_data;         // Data Payload
    logic [NBYTES-1:0]     lp_valid;        // 1 valid bit per byte
    logic                  lp_irdy;         // Data Link layer ready to send
    logic [3:0]            lp_state_req;    // Power/Link state request
    // logic                  pl_trdy;
    // Framing Flags (1 bit per byte for variable-length packets)
    logic [NBYTES-1:0]     lp_tlpstart;
    logic [NBYTES-1:0]     lp_tlpend;
    logic [NBYTES-1:0]     lp_dlpstart;
    logic [NBYTES-1:0]     lp_dlpend;

    
    // Rx Path (PHY -> DLL) : "pl_" signals
    logic [(NBYTES*8)-1:0] pl_data;        
    logic [NBYTES-1:0]     pl_valid;       
    logic                  pl_trdy;        // PHY ready to accept data
    logic [3:0]            pl_state_sts;   // Power/Link state status
    logic                  pl_lnk_up;      // Link Up status

    // Received Framing Flags
    logic [NBYTES-1:0]     pl_tlpstart;
    logic [NBYTES-1:0]     pl_tlpend;
    logic [NBYTES-1:0]     pl_dlpstart;
    logic [NBYTES-1:0]     pl_dlpend;
    logic [NBYTES-1:0]     pl_tlpedb;      // TLP End Bad (Error injection)

    //TODO : RnD these signals
    // Static Configuration & Tie-offs (Driven by Mock PHY)
    logic [2:0]            pl_lnk_cfg;     // Link width
    logic [2:0]            pl_speedmode;   // Link speed
    logic                  pl_inband_pres; // In-band presence
    logic                  pl_error;       // Recoverable framing error
    logic                  pl_cerror;      // Correctable error


    // Driver: drives the lp_* (DLL -> PHY) outputs, 1 time-step after posedge
    clocking cb_drv @(posedge lclk);
        default output #1step;
        output lp_data;
        output lp_valid;
        output lp_irdy;
        output lp_state_req;
        output lp_tlpstart;
        output lp_tlpend;
        output lp_dlpstart;
        output lp_dlpend;
        output pl_lnk_up;
    endclocking

    // TX Monitor: samples what the driver is sending on lp_* and checks pl_trdy handshake
    clocking cb_mon_tx @(posedge lclk);
        default input #1step;
        input lp_data;
        input lp_valid;
        input lp_irdy;
        input lp_tlpstart;
        input lp_tlpend;
        input lp_dlpstart;
        input lp_dlpend;
        input pl_trdy;
        input pl_lnk_up; //TODO : add more signals to monitor for better checking and coverage
    endclocking

    // RX Monitor: samples what the PHY is sending on pl_* signals
    clocking cb_mon_rx @(posedge lclk);
        default input #1step;
        input pl_data;
        input pl_valid;
        input pl_trdy;
        input pl_tlpstart;
        input pl_tlpend;
        input pl_dlpstart;
        input pl_dlpend;
        input pl_tlpedb;
        input pl_lnk_up;
    endclocking

endinterface