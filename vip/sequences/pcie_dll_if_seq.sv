class pcie_dll_if_seq extends uvm_sequence #(pcie_dll_if_seq_item);

    pcie_dll_if_seq_item seq_item;

    `uvm_object_utils(pcie_dll_if_seq)

    function new (string name = "pcie_dll_if_seq");
        super.new(name);
    endfunction

    task body();
        seq_item = pcie_dll_if_seq_item::type_id::create("seq_item");

        start_item(seq_item);
        if(!seq_item.randomize() with {drop_link == 1;}) begin
            `uvm_error("SEQ_ITEM_RANDOMIZE", "Failed to randomize seq_item")
        end
        `uvm_info("IF_SEQ", $sformatf("-----Starting sequence with drop_link = %b, cycles_num = %0d at time = %0t------", seq_item.drop_link, seq_item.cycles_num, $time), UVM_LOW)
        finish_item(seq_item);
        `uvm_info("IF_SEQ", $sformatf("-----Finished sequence with drop_link = %b, cycles_num = %0d at time = %0t------", seq_item.drop_link, seq_item.cycles_num, $time), UVM_LOW)
    endtask

endclass