class send_single_packet extends pcie_dll_base_seq;

  pcie_dll_base_seq_item item_to_send; //the item to send, can be either tlp or dllp, but currently we only have dllp items
  pcie_dll_dllp_seq_item dllp_item;
  pcie_dll_tlp_seq_item tlp_item;

  `uvm_object_utils(send_single_packet)

  function new(string name = "send_single_packet");
    super.new(name);
  endfunction

  task body();
    // try casting it to dllp item
    if($cast(dllp_item, item_to_send)) begin

      start_item(dllp_item);
      finish_item(dllp_item);

    end 
    //try ccasting it to tlp item
    else if($cast(tlp_item, item_to_send)) begin
    
      start_item(tlp_item);
      finish_item(tlp_item);

    end 
    
    else begin

      `uvm_warning("SEQ", "The item to send is neither a DLLP nor a TLP. No item will be sent.")
    
    end

  endtask

endclass : send_single_packet

