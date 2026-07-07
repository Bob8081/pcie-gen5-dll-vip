class crc_generator ;

    static function automatic bit [15:0] calculate_pcie_crc (bit [31:0] data);
    bit [15:0] crc_reg = 16'hFFFF;  
    bit [15:0] poly = 16'h8005;     

    for (int i = 31; i >= 0; i--) begin
      if (crc_reg[15] ^ data[i]) begin
        crc_reg = (crc_reg << 1) ^ poly;
      end else begin
        crc_reg = crc_reg << 1;
      end
    end
    
    return ~crc_reg; 
  endfunction

endclass : crc_generator