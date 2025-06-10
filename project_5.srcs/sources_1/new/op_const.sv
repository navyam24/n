package op_const_pkg;
    typedef enum bit[6:0] {
        STORE =    7'b0100011,
        OPIMM =    7'b0010011,
        LOAD =     7'b0000011,
        BRANCH =   7'b1100011,
        OP =       7'b0110011,
        LUI =      7'b0110111,
        MADD =     7'b1000011,
        LOADFP =   7'b0000111,
        STOREFP =  7'b0100111,
        MSUB =     7'b1000111,
        JALR =     7'b1100111,
        NMSUB =    7'b1001011,
        NMADD =    7'b1001111,
        OPFP =     7'b1010011,
        AUIPC =    7'b0010111,
        OP32 =     7'b0111011,
        OPIMM32 =  7'b0011011,
        JAL =      7'b1101111
    } e_op;
    
    typedef enum bit[2:0] {
        ADDI  = 3'b000,
        SLTI  = 3'b010,
        SLTIU = 3'b011,
        XORI  = 3'b100,
        ORI   = 3'b110,
        ANDI  = 3'b111,
        SLLI  = 3'b001,
        SRLI  = 3'b101
        // SRAI  = 3'b101
    } e_funct_opimm;
    
    typedef enum bit[2:0] {
        BEQ = 3'b000,
        BNE = 3'b001,
        BLT = 3'b100,
        BGE = 3'b101,
        BLTU = 3'b110,
        BGEU = 3'b111
    } e_funct_branch;
    
    typedef enum bit[9:0] {
        ADD =  10'b0000000000,
        SLT =  10'b0000000010,
        SLTU = 10'b0000000011,
        AND =  10'b0000000111,
        OR =   10'b0000000110,
        XOR =  10'b0000000100,
        SLL =  10'b0000000001,
        SRL =  10'b0000000101,
        SUB =  10'b0100000000,
        SRA =  10'b0100000101,
    
        // RV32M
        MUL =    10'b0000001000,
        MULH =   10'b0000001001,
        MULHSU = 10'b0000001010,
        MULHU =  10'b0000001011,
        DIV =    10'b0000001100,
        DIVU =   10'b0000001101,
        REM =    10'b0000001110,
        REMU =   10'b0000001111
    } e_funct_op;
    
    typedef enum bit[4:0] {
        FADD =  5'b00000,
        FSUB =  5'b00001,
        FMUL =  5'b00010,
        FDIV =  5'b00011,
        FSQRT = 5'b01011
    } e_funct5_float;
endpackage