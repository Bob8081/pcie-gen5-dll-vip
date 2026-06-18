class pcie_dll_common_checks extends uvm_object;
  //TODO : add checks for timing violation in initfc packets in recieving and transmitting
  //TODO : predict and check for current state
  `uvm_object_utils(pcie_dll_common_checks)

  function new(string name = "pcie_dll_common_checks");
    super.new(name);
  endfunction

  
  // DLCMSM State Transition Checks 

  /**
   * check_init_trigger
   * @brief Verify that DL_Inactive -> DL_Init transition occurs only after pl_lnk_up == 1
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param pl_lnk_up Link up status from PHY
   * @return 1 if check passes, 0 if check fails (FATAL)
   * @severity FATAL - Link must be UP before exiting DL_Inactive
   */
  function bit check_init_trigger(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit pl_lnk_up
  );
    bit is_init_transition = (prev_state == DL_INACTIVE) && 
                             ((curr_state == DL_FEATURE_EXCH) || 
                              (curr_state == DL_INIT_FC1));
    
    if (is_init_transition && !pl_lnk_up) begin
      return 0;
    end
    return 1;
  endfunction

  /**
   * check_valid_transition
   * @brief Verify that the DLCMSM follows the allowed Phase 1 sequence:
   *        DL_INACTIVE -> DL_FEATURE_EXCH -> DL_INIT_FC1 -> DL_INIT_FC2 -> DL_ACTIVE
   *        or DL_INACTIVE -> DL_INIT_FC1 -> DL_INIT_FC2 -> DL_ACTIVE
    *        or DL_ACTIVE -> DL_INACTIVE
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @return 1 if the transition is valid, 0 if it is illegal (FATAL)
   * @severity FATAL - Any deviation from the allowed state order is illegal
   */
  function bit check_valid_transition(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state
  );
    bit valid_transition;

    case (prev_state)
      DL_INACTIVE:     valid_transition = (curr_state == DL_FEATURE_EXCH) ||
                                          (curr_state == DL_INIT_FC1);
      DL_FEATURE_EXCH: valid_transition = (curr_state == DL_INIT_FC1);
      DL_INIT_FC1:     valid_transition = (curr_state == DL_INIT_FC2);
      DL_INIT_FC2:     valid_transition = (curr_state == DL_ACTIVE);
      DL_ACTIVE:       valid_transition = (curr_state == DL_INACTIVE);
      default:         valid_transition = 1'b0;
    endcase

    return valid_transition;
  endfunction

  /**
   * check_state_stability
   * @brief Verify that once the DLCMSM reaches DL_ACTIVE, it does not regress
   *        to DL_INIT_FC1 or DL_INACTIVE while pl_lnk_up remains high.
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param pl_lnk_up Link up status from PHY
   * @return 1 if the state remains stable, 0 if it regresses (FATAL)
   * @severity FATAL - DL_ACTIVE must not regress while link up is asserted
   */
  function bit check_state_stability(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit pl_lnk_up
  );
    bit regresses_from_active;

    regresses_from_active = (prev_state == DL_ACTIVE) && pl_lnk_up &&
                            ((curr_state == DL_INACTIVE) ||
                             (curr_state == DL_INIT_FC1));

    if (regresses_from_active) begin
      return 0;
    end

    return 1;
  endfunction

  /**
   * check_active_gate_fi1
   * @brief Verify that DL_INIT_FC1 -> DL_INIT_FC2 occurs only after FI1 is set.
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param fi1_set FI1 gate flag from state manager
   * @return 1 if the gate is satisfied, 0 if it is not (FATAL)
   * @severity FATAL - DL_INIT_FC2 requires FI1 to be asserted first
   */
  function bit check_active_gate_fi1(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit fi1_set
  );
    bit is_active_transition;

    is_active_transition = (prev_state == DL_INIT_FC1) && (curr_state == DL_INIT_FC2);

    if (is_active_transition && !fi1_set) begin
      return 0;
    end

    return 1;
  endfunction

  /**
   * check_active_gate_fi2
   * @brief Verify that DL_INIT_FC2 -> DL_ACTIVE occurs only after FI2 is set.
   * @param prev_state Previous state before transition
   * @param curr_state Current state after transition
   * @param fi2_set FI2 gate flag from state manager
   * @return 1 if the gate is satisfied, 0 if it is not (FATAL)
   * @severity FATAL - DL_ACTIVE requires FI2 to be asserted first
   */
  function bit check_active_gate_fi2(
    pcie_dlcmsm_state_e prev_state,
    pcie_dlcmsm_state_e curr_state,
    bit fi2_set
  );
    bit is_active_transition;

    is_active_transition = (prev_state == DL_INIT_FC2) && (curr_state == DL_ACTIVE);

    if (is_active_transition && !fi2_set) begin
      return 0;
    end

    return 1;
  endfunction

  /**
   * check_fc_strict_order
   * @brief Verify that DLLPs are observed in strict order:
   *        expected_first, expected_second, expected_third.
   * @param dllp_type Observed DLLP type from the RX monitor
   * @param order_step Current ordering step (0, 1, 2, 3=done)
   * @param expected_first Expected type for step 0
   * @param expected_second Expected type for step 1
   * @param expected_third Expected type for step 2
   * @param next_order_step Updated ordering step after the current DLLP
   * @return 1 if the observed type matches the expected order, 0 otherwise
   * @severity ERROR - DLLPs must arrive in the exact expected order
   */
  function bit check_fc_strict_order(
    pcie_dllp_type_e dllp_type,
    int unsigned order_step,
    pcie_dllp_type_e expected_first,
    pcie_dllp_type_e expected_second,
    pcie_dllp_type_e expected_third,
    output int unsigned next_order_step
  );
    bit valid_order;

    next_order_step = order_step;
    valid_order = 1'b1;

    case (order_step)
      0: begin
        if (dllp_type == expected_first) begin
          next_order_step = 1;
        end else begin
          valid_order = 1'b0;
        end
      end

      1: begin
        if (dllp_type == expected_second) begin
          next_order_step = 2;
        end else begin
          valid_order = 1'b0;
        end
      end

      2: begin
        if (dllp_type == expected_third) begin
          next_order_step = 3;
        end else begin
          valid_order = 1'b0;
        end
      end

      default: begin
        next_order_step = 3;
      end
    endcase

    return valid_order;
  endfunction


  /**
   * check_feature_reserved_zero
   * @brief Verify that bits [22:1] of the received Feature Supported field are
   *        all zero. Only bit 0 (Scaled Flow Control) is a defined feature bit;
   *        all other bits are reserved and must be transmitted as zero by the
   *        partner (PCIe Base Spec Rev 5.0).
   * @param feature_support The 23-bit feature_support field from the received
   *        DLLP_FEATURE_REQ, as decoded by pcie_dll_dllp_seq_item::unpack().
   * @return 1 if bits [22:1] are all zero (check passes), 0 otherwise (ERROR)
   * @severity ERROR - Reserved bits must be zero; a non-zero value indicates
   *           a malformed or non-compliant Feature DLLP from the partner.
   */
  function bit check_feature_reserved_zero(
    bit [22:0] feature_support
  );
    // Mask out bit 0; the remaining bits [22:1] must all be zero.
    if (feature_support[22:1] != 22'b0) begin
      return 0;
    end
    return 1;
  endfunction

endclass : pcie_dll_common_checks
