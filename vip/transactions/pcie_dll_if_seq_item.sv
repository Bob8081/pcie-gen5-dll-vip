class pcie_dll_if_seq_item extends uvm_sequence_item;

    rand bit drop_link;
    rand int unsigned cycles_num;
    //TODO : add more link managment related fields 
    //TODO : maybe make the command to use on the interface an enum with all the possible link management commands 
    //(e.g., reset, link retrain, etc..) instead of just a bit for reset

    `uvm_object_utils(pcie_dll_if_seq_item)

    function new(string name = "pcie_dll_if_seq_item");
        super.new(name);
    endfunction

    constraint delay_duration {cycles_num > 0 && cycles_num < 10;}

endclass