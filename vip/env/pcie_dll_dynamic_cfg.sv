class pcie_dll_dynamic_cfg extends uvm_object;

    //FC credits
    // Posted credits
    int unsigned partner_hdr_fc_limit_p;
    int unsigned partner_data_fc_limit_p;
    int unsigned partner_hdr_scale_p;
    int unsigned partner_data_scale_p;
    //not scaled values saved for comparsion with the recieved packets payload
    int unsigned partner_hdr_fc_limit_p_not_scaled;
    int unsigned partner_data_fc_limit_p_not_scaled;

    // Non-Posted credits
    int unsigned partner_hdr_fc_limit_np;
    int unsigned partner_data_fc_limit_np;
    int unsigned partner_hdr_scale_np;
    int unsigned partner_data_scale_np;
    //not scaled values saved for comparsion with the recieved packets payload
    int unsigned partner_hdr_fc_limit_np_not_scaled;
    int unsigned partner_data_fc_limit_np_not_scaled;
    
    // Completion credits
    int unsigned partner_hdr_fc_limit_cpl;
    int unsigned partner_data_fc_limit_cpl;
    int unsigned partner_hdr_scale_cpl;
    int unsigned partner_data_scale_cpl;
    //not scaled values saved for comparsion with the recieved packets payload
    int unsigned partner_hdr_fc_limit_cpl_not_scaled;
    int unsigned partner_data_fc_limit_cpl_not_scaled;
 

    `uvm_object_utils(pcie_dll_dynamic_cfg)

    function new(string name = "pcie_dll_dynamic_cfg");
        super.new(name);
    endfunction
    
    function void set_credits_value(pcie_dllp_type_e t, int unsigned hdr_fc, int unsigned data_fc,int unsigned hdr_scale,int unsigned data_scale);

        if (t == DLLP_INITFC1_P) begin
            partner_hdr_fc_limit_p_not_scaled = hdr_fc;
            partner_data_fc_limit_p_not_scaled = data_fc;
            partner_hdr_scale_p = hdr_scale;
            partner_data_scale_p = data_scale;
            calculate_not_scaled_credits(hdr_fc, data_fc, hdr_scale, data_scale,
                                        partner_hdr_fc_limit_p, partner_data_fc_limit_p);
        end
        else if (t == DLLP_INITFC1_NP) begin
            partner_hdr_fc_limit_np_not_scaled = hdr_fc;
            partner_data_fc_limit_np_not_scaled = data_fc;
            partner_hdr_scale_np = hdr_scale;
            partner_data_scale_np = data_scale;
            calculate_not_scaled_credits(hdr_fc, data_fc, hdr_scale, data_scale,
                                        partner_hdr_fc_limit_np, partner_data_fc_limit_np);
        end
        else if (t == DLLP_INITFC1_CPL) begin
            partner_hdr_fc_limit_cpl_not_scaled = hdr_fc;
            partner_data_fc_limit_cpl_not_scaled = data_fc;
            partner_hdr_scale_cpl = hdr_scale;
            partner_data_scale_cpl = data_scale;
            calculate_not_scaled_credits(hdr_fc, data_fc, hdr_scale, data_scale,
                                        partner_hdr_fc_limit_cpl, partner_data_fc_limit_cpl);
        end
        
        `uvm_info("CRD SAVED",$sformatf("Recieved the credits for %s \n current credits saved for each type : \n Posted : hdr = %d , data = %d \n NON_Posted : hdr =%d, data= %d \n Compeletion : hdr = %d , data= %d ",
                    t.name(),partner_hdr_fc_limit_p,partner_data_fc_limit_p,partner_hdr_fc_limit_np,partner_data_fc_limit_np,partner_hdr_fc_limit_cpl,
                    partner_data_fc_limit_cpl),UVM_LOW)
    endfunction

    function void calculate_not_scaled_credits(int unsigned scaled_hdr_fc, int unsigned scaled_data_fc, int unsigned hdr_scale, int unsigned data_scale,
                                                                output int unsigned not_scaled_hdr_fc, output int unsigned not_scaled_data_fc);
        not_scaled_hdr_fc = 0;
        not_scaled_data_fc = 0;

        case (hdr_scale)
            2'b00,2'b01 : not_scaled_hdr_fc =  scaled_hdr_fc;
            2'b10 :       not_scaled_hdr_fc = scaled_hdr_fc << 2;
            2'b11 :       not_scaled_hdr_fc = scaled_hdr_fc << 4;
        endcase
        
        case (data_scale)
            2'b00,2'b01 : not_scaled_data_fc =  scaled_data_fc;
            2'b10 :       not_scaled_data_fc = scaled_data_fc << 2;
            2'b11 :       not_scaled_data_fc = scaled_data_fc << 4;
        endcase
        
    endfunction
endclass : pcie_dll_dynamic_cfg