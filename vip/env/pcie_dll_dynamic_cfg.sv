class pcie_dll_dynamic_cfg extends uvm_object;

    pcie_dll_role_e role;

    //FC credits associative array
    pcie_fc_credits_values_s partner_credits[pcie_fc_type_e];

    bit partner_feature_valid;
    bit [22 : 0] partner_feature_support;

    `uvm_object_utils(pcie_dll_dynamic_cfg)

    function new(string name = "pcie_dll_dynamic_cfg");
        super.new(name);

        //initialize each struct with its type equal to its index
        partner_credits[FC_POSTED].fc_type=FC_POSTED;
        partner_credits[FC_NON_POSTED].fc_type=FC_NON_POSTED;
        partner_credits[FC_CPL].fc_type = FC_CPL;

    endfunction
    
    function void set_credits_value(pcie_dllp_type_e t, int unsigned hdr_fc, int unsigned data_fc,int unsigned hdr_scale,int unsigned data_scale);

        pcie_fc_type_e target_type;

        if (t == DLLP_INITFC1_P) begin
            target_type = FC_POSTED;
        end
        else if (t == DLLP_INITFC1_NP) begin
           target_type = FC_NON_POSTED;
        end
        else if (t == DLLP_INITFC1_CPL) begin
            target_type = FC_CPL;
        end
        else
        begin
            `uvm_error("CRD_ERR",$sforamtf("can't save credits from a %s packet type",t.name()))
            return;
        end

        partner_credits[target_type].hdr_limit = hdr_fc;
        partner_credits[target_type].data_limit = data_fc;
        partner_credits[target_type].hdr_scale = hdr_scale;
        partner_credits[target_type].data_scale = data_scale;
        calculate_absolute_credits(hdr_fc, data_fc, hdr_scale, data_scale,
                                    partner_credits[target_type].absolute_hdr_limit, partner_credits[target_type].absolute_data_limit);
                                    

        `uvm_info("CRD_SAVED", $sformatf("device with %s saved partner credits of %s type. ", role, t.name()), UVM_LOW)
        view_credits();
        
    endfunction


    function void calculate_absolute_credits(int unsigned scaled_hdr_fc, int unsigned scaled_data_fc, int unsigned hdr_scale, int unsigned data_scale,
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


    function void view_credits();
        foreach(partner_credits[i])
        begin
            `uvm_info("CRD_STATUS", $sformatf("partner %s credits : hdr_limit = %0d , data_limit = %0d , hdr_scale = %0d, data_scale = %0d , total_hdr_limit = %0d , total_data_limit = %0d",
                                                i.name(), partner_credits[i].hdr_limit, partner_credits[i].data_limit, partner_credits[i].hdr_scale, partner_credits[i].data_scale,
                                                partner_credits[i].absolute_hdr_limit, partner_credits[i].absolute_data_limit), UVM_LOW)
        end
    endfunction 

endclass : pcie_dll_dynamic_cfg