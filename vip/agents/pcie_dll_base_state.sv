//class for the base state which all the states will extend from defining the common proprirties and methods
typedef class pcie_dll_state_mgr; //AI TIP: Forward declaration to avoid circular dependency between the state manager and the states

class pcie_dll_base_state extends uvm_object;

    `uvm_object_utils(pcie_dll_base_state) 

     pcie_dlcmsm_state_e next_state; 

    function new(string name = "pcie_dll_base_state");
        super.new(name);
    endfunction

    // main task...here goes all the state logic and the fatal error to prevent non-overriding of this task in the child states
    virtual task start_state(pcie_dll_state_mgr manager);
        `uvm_fatal("BASE_STATE", $sformatf("The state '%s' forgot to override the start_state() task", get_name()))
    endtask

    // Override get_full_name so your logs show all the information needed about this state
    function string get_full_name();
        // Return just the name of the state (e.g., "dl_init_state")
        return get_name(); 
    endfunction

endclass