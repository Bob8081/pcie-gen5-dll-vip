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

    // =========================================================
    // SYSTEMVERILOG ASSERTIONS (SVA)
    // =========================================================
   

    /*_____________the framing and valid signals______________*/

    //1 - check that if valid is set then irdy is set as well (no valid without irdy)
    property lp_valid_irdy_relation;
    @(posedge lclk) disable iff (!rst_n || !pl_lnk_up)
    (|lp_valid) |-> lp_irdy;
    endproperty
    
    //2 - check that packet starts at a byte less than its end (no negative length packets)
    property packet_start_end_valid (pkt_start, pkt_end);
        @(posedge lclk) disable iff (!rst_n || !pl_lnk_up)
        ((|pkt_start) && (|pkt_end)) |->
        (pkt_start <= pkt_end); 
    endproperty  

    //3 - check that framing singals are right (no 2 ones set in one cycle)
    property framing_signals_valid;
        @(posedge lclk) disable iff (!rst_n || !pl_lnk_up)
        $onehot0(lp_tlpstart) && 
        $onehot0(lp_tlpend)   &&
        $onehot0(lp_dlpstart) && 
        $onehot0(lp_dlpend);
    endproperty

    //4 - check that the tlp and dllp -if sent on same cycle- dont start or end on same byte
    property no_tlp_dllp_overlap;
        @(posedge lclk) disable iff (!rst_n || !pl_lnk_up)
        ((|lp_tlpstart) && (|lp_dlpstart)) |->
        (lp_tlpstart & lp_dlpstart) == '0; 
    endproperty  

    // 5 - lp_valid in correct range of start and end flags
    property lp_valid_between_limits;
        @(posedge lclk) disable iff (!rst_n || !pl_lnk_up)
        
        (|lp_tlpstart || |lp_dlpstart) |-> 
        
        
        (lp_valid == (((|lp_tlpstart) ? (lp_tlpend | (lp_tlpend - lp_tlpstart)) : '0) 
                            | ((|lp_dlpstart) ? (lp_dlpend | (lp_dlpend - lp_dlpstart)) : '0))
        );
    endproperty

    /*__________control signals reset and pl_lnkup___________*/

    //6 - pl_lnk_up porperty
    property p_lnk_down_flush;
        @(posedge lclk) disable iff (!rst_n)
        (!pl_lnk_up) |->
        (lp_irdy     == '0) &&
        (pl_trdy     == '0) &&
        (lp_valid    == '0) &&
        (lp_data     == '0) && 
        (lp_dlpstart == '0) &&
        (lp_dlpend   == '0) &&
        (lp_tlpstart == '0) &&
        (lp_tlpend   == '0);
    endproperty

    // 7 - reset property
    property reset_property;
        @(posedge lclk) 
        (!rst_n) |->
        (pl_lnk_up   == '0) &&
        (lp_irdy     == '0) &&
        (pl_trdy     == '0) &&
        (lp_valid    == '0) &&
        (lp_data     == '0) && 
        (lp_dlpstart == '0) &&
        (lp_dlpend   == '0) &&
        (lp_tlpstart == '0) &&
        (lp_tlpend   == '0);
    endproperty

    /*________no X on pins___________*/

    // 8 - check for unknown state on pins
    property no_x_on_pins;
        @(posedge lclk) 
        !$isunknown({
            lp_irdy, 
            pl_trdy, 
            lp_valid, 
            pl_lnk_up, 
            lp_tlpstart,
            lp_tlpend,
            lp_dlpstart,
            lp_dlpend
        });
    endproperty
    
    
   

    CHK_VALID_IRDY: assert property (lp_valid_irdy_relation)
        else $error("LPIF Protocol Violation: lp_valid asserted but lp_irdy is 0 at time %0t", $time);

    CHK_TLP_BOUNDS: assert property (packet_start_end_valid(lp_tlpstart, lp_tlpend))
        else $error("LPIF Framing Violation: TLP End bit position is before Start bit at time %0t", $time);

    CHK_DLP_BOUNDS: assert property (packet_start_end_valid(lp_dlpstart, lp_dlpend))
        else $error("LPIF Framing Violation: DLLP End bit position is before Start bit at time %0t", $time);
    
    CHK_VALID_BOUNDS: assert property (lp_valid_between_limits)
        else $error("LPIF Framing Violation: lp_valid bits are set outside the bounds of the packet start/end flags at time %0t", $time);

    CHK_ONEHOT_FRAMING: assert property (framing_signals_valid)
        else $error("LPIF Framing Violation: Multiple start/end bits detected for a single packet type at time %0t", $time);

    CHK_TLP_DLLP_COLLISION: assert property (no_tlp_dllp_overlap)
        else $error("LPIF Framing Violation: TLP and DLLP start flags collided on the same byte lane at time %0t", $time);

    CHK_LNK_DOWN_FLUSH: assert property (p_lnk_down_flush)
        else $error("LPIF Violation: DLL did not flush the bus when pl_lnk_up went to 0 at time %0t", $time);

    CHK_RESET_QUIET: assert property (reset_property)
        else $error("LPIF Violation: DLL control signals were driven while rst_n was 0 at time %0t", $time);

    CHK_NO_X_STATES: assert property (no_x_on_pins)
        else $error("LPIF FATAL: One or more critical control/framing signals evaluated to X or Z at time %0t", $time);

    
endinterface