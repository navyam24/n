package const_pkg;

    // Parameters
    parameter num_regs = 32;
    parameter data_width = 32;
    parameter addr_width = 32;
    parameter instr_width = 32;
    parameter reg_sel_width = $clog2(num_regs);

    // Enum for states
    typedef enum bit[4:0] {
        C0,
        C1,
        C2
    } e_state;

endpackage