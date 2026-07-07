class crc16_generator ;

  static function automatic bit [15:0] calculate_dllp_crc (bit [31:0] data);
    bit [15:0] crc_reg = 16'hFFFF;
    bit [15:0] poly = 16'h100B;
    bit [15:0] mapped_crc;

    for (int i = 0; i < 32; i++) begin
      if (crc_reg[15] ^ data[i]) begin
        crc_reg = (crc_reg << 1) ^ poly;
      end else begin
        crc_reg = crc_reg << 1;
      end
    end

    // Invert and do bit mapping
    crc_reg = ~crc_reg;
    for (int i = 0; i < 8; i++) begin
      mapped_crc[i]   = crc_reg[7-i];
      mapped_crc[i+8] = crc_reg[15-i];
    end

    return mapped_crc;
  endfunction

endclass : crc16_generator