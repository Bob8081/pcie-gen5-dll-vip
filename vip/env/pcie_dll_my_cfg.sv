class pcie_dll_my_cfg extends uvm_object;
    
    pcie_dll_role_e role;
    int counter_fc1;
    int counter_fc2;
    bit fi1_set;
    bit fi2_set;
    pcie_dlcmsm_state_e dlsm_state; //to track the current state of the DLCM state machine, which is used in some states to decide the next steps

    `uvm_object_utils(pcie_dll_my_cfg)

    function new(string name = "pcie_dll_my_cfg");
        super.new(name);
    endfunction

    function void view_state();
        `uvm_info("MY_CFG", $sformatf("My role is %s, current state is %s, counter_fc1 is %0d, counter_fc2 is %0d, fi1_set is %0b, fi2_set is %0b", role.name(), dlsm_state.name(), counter_fc1, counter_fc2, fi1_set, fi2_set), UVM_LOW)
    endfunction
    //TODO : add reset function
    function void reset();
        counter_fc1 = 0;
        counter_fc2 = 0;
        fi1_set = 0;
        fi2_set = 0;
    endfunction
endclass