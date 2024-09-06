package riscv_pkg;
    typedef enum logic [6:0] {
        OP_IMM = 7'b0010011,
        LUI = 7'b0110111,
        AUIPC = 7'b0010111,
        OP = 7'b0110011,
        JAL = 7'b1101111,
        JALR = 7'b1100111,
        BRANCH = 7'b1100011,
        LOAD = 7'b0000011,
        STORE = 7'b0100011,
        MISC_MEM = 7'b0001111,
        SYSTEM = 7'b1110011,
        AMO = 7'b0101111,
        F_OP = 7'b1010011,
        F_LD = 7'b0000111,
        F_ST = 7'b0100111
    } opcode;
    
    typedef enum logic [1:0] {
        M = 2'b00,
        E = 2'b01,
        S = 2'b10,
        I = 2'b11
    } MESI;
    
    typedef enum logic [2:0] {
        M_B = 3'b000,
        M_H = 3'b001,
        M_W = 3'b010,
        M_D = 3'b011,
        M_BU = 3'b100,
        M_HU = 3'b101,
        M_WU = 3'b110,
        M_DU = 3'b111
    } MemWidth;
    
    typedef enum logic [4:0] {
        ALUCTL_ADD = 5'b00000,
        ALUCTL_ADDU = 5'b00001,
        ALUCTL_SUB = 5'b00010,
        ALUCTL_SUBU = 5'b00011,
        ALUCTL_AND = 5'b00100,
        ALUCTL_OR = 5'b00101,
        ALUCTL_XOR = 5'b00110,
        ALUCTL_SLT = 5'b00111,
        ALUCTL_SLTU = 5'b01000,
        ALUCTL_SLL = 5'b01001,
        ALUCTL_SRL = 5'b01010,
        ALUCTL_SRA = 5'b01011,
        ALUCTL_AUIPC = 5'b01100,
        ALUCTL_BEQ = 5'b01101,
        ALUCTL_BNE = 5'b01110,
        ALUCTL_BGE = 5'b01111,
        ALUCTL_BGEU = 5'b10000,
        ALUCTL_BLT = 5'b10001,
        ALUCTL_BLTU = 5'b10010,
        ALUCTL_MUL = 5'b10011,
        ALUCTL_MULH = 5'b10100,
        ALUCTL_MULHSU = 5'b10101,
        ALUCTL_MULHU = 5'b10110,
        ALUCTL_DIV = 5'b10111,
        ALUCTL_DIVU = 5'b11000,
        ALUCTL_REM = 5'b11001,
        ALUCTL_REMU = 5'b11010
    } AluCtl;
    
    typedef enum logic [2:0] {
        CSRRW = 3'b001,
        CSRRS = 3'b010,
        CSRRC = 3'b011,
        CSRRWI = 3'b101,
        CSRRSI = 3'b110,
        CSRRCI = 3'b111
    } funct3_CSR;
    
    typedef enum logic [2:0]{
        BEQ = 3'b000,
        BNE = 3'b001,
        BLT = 3'b100,
        BGE = 3'b101,
        BLTU = 3'b110,
        BGEU = 3'b111
    } funct3_branch;
    
    typedef enum logic [2:0] {
        f3_ADD = 3'b000,
        f3_SLT = 3'b010,
        f3_SLTU = 3'b011,
        f3_AND = 3'b111,
        f3_OR = 3'b110,
        f3_XOR = 3'b100,
        f3_SL = 3'b001,
        f3_SR = 3'b101
    } funct3;
    
    typedef enum logic {
        AMO_LR = 0,
        AMO_SC = 1
    } AmoType;    
    
    typedef enum logic [6:0] {
        f7_standard =7'b0000000,
        f7_inverted = 7'b0100000,
        f7_multiply = 7'b0000001
    } funct7;
    
    typedef enum logic {
        WRITE = 0,
        READ =1
    } MemAccessType;
    
    typedef enum logic {
        NOT_TAKEN = 0,
        TAKEN = 1
    } BranchOutcome;
    

endpackage
