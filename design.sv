// Code your design here
// ---------------- MAR + RAM ----------------
// port order: mar_in, clk, adress, ram_in, ram_out, common_bus, select
module memory_adress_reg(
  input mar_in,
  input clk,
  input [3:0] adress,        // from the common bus
  input ram_in,
  input ram_out,
  inout [7:0] common_bus,
  output reg [3:0] select
);
  reg [7:0] ram [0:15];      // 16 bytes of memory

  initial begin
    // the program: top 4 bits = opcode, bottom 4 bits = address/value
    ram[0]  = 8'h40; // LDI 0
    ram[1]  = 8'h3D; // STA 13      i = 0
    ram[2]  = 8'h0D; // LDA 13      <- loop start
    ram[3]  = 8'h70; // OUT         show i
    ram[4]  = 8'h1E; // ADD 14      A = i + 3
    ram[5]  = 8'h3D; // STA 13      i = i + 3
    ram[6]  = 8'h2F; // SUB 15      A = i - 15 (sets zero flag)
    ram[7]  = 8'h69; // BEQ 9       if i == 15 go to 9
    ram[8]  = 8'h52; // JMP 2       else go back to loop start
    ram[9]  = 8'hF0; // HLT
    ram[10] = 8'h00;
    ram[11] = 8'h00;
    ram[12] = 8'h00;
    ram[13] = 8'h00; // variable i
    ram[14] = 8'h03; // the step (3)
    ram[15] = 8'h0F; // the limit (15)
  end

  always @(posedge clk) begin
    if (mar_in) select <= adress;
    if (ram_in) ram[select] <= common_bus;
  end

  assign common_bus = ram_out ? ram[select] : 8'bz;
endmodule

// ---------------- Program counter ----------------
// port order: pc_inc, pc_in, pc_out, clk, rst, common_bus
module pc(
  input pc_inc,              // count up by 1
  input pc_in,               // load from bus (jump)
  input pc_out,              // put count on bus
  input clk,
  input rst,
  inout [7:0] common_bus
);
  reg [3:0] count;
  always @(posedge clk) begin
    if (rst) count <= 0;
    else if (pc_in) count <= common_bus[3:0];
    else if (pc_inc) count <= count + 1;
  end
  assign common_bus = pc_out ? {4'b0, count} : 8'bz;
endmodule

// ---------------- Registers A and B ----------------
// port order: common_bus, rega_in, regb_in, rega_out, regb_out, clk, alu_from_a, alu_from_b
module registers(
  inout [7:0] common_bus,
  input rega_in,
  input regb_in,
  input rega_out,
  input regb_out,
  input clk,
  output reg [7:0] alu_from_a,
  output reg [7:0] alu_from_b
);
  always @(posedge clk) begin
    if (rega_in) alu_from_a <= common_bus;
    if (regb_in) alu_from_b <= common_bus;
  end
  assign common_bus = rega_out ? alu_from_a :
                      regb_out ? alu_from_b : 8'bz;
endmodule

// ---------------- ALU + flags ----------------
// port order: a, b, alu_out, sub, flags_in, clk, common_bus, aluout, z, c
module alu(
  input [7:0] a,
  input [7:0] b,
  input alu_out,             // put result on bus
  input sub,                 // 1 = subtract, 0 = add
  input flags_in,            // save z and c
  input clk,
  inout [7:0] common_bus,
  output [7:0] aluout,
  output reg z,
  output reg c
);
  wire [8:0] result = sub ? ({1'b0,a} + {1'b0,~b} + 9'd1)   // a + ~b + 1
                          : ({1'b0,a} + {1'b0,b});
  assign aluout = result[7:0];

  always @(posedge clk) begin
    if (flags_in) begin
      z <= (result[7:0] == 8'd0);   // zero flag
      c <= result[8];               // carry flag
    end
  end

  assign common_bus = alu_out ? aluout : 8'bz;
endmodule

// ---------------- Display (hex digit on 7 segments) ----------------
// port order: common_bus, display_in, clk, rst, seg1..seg7, shown
module display_from_0_to7(
  input [7:0] common_bus,
  input display_in,
  input clk,
  input rst,
  output seg1,
  output seg2,
  output seg3,
  output seg4,
  output seg5,
  output seg6,
  output seg7,
  output reg [3:0] shown     // the number currently displayed
);
  reg [6:0] seg;
  always @(posedge clk) begin
    if (rst) shown <= 0;
    else if (display_in) shown <= common_bus[3:0];
  end

  always @(*) begin
    case (shown)             // segments a b c d e f g
      4'h0: seg = 7'b1111110;
      4'h1: seg = 7'b0110000;
      4'h2: seg = 7'b1101101;
      4'h3: seg = 7'b1111001;
      4'h4: seg = 7'b0110011;
      4'h5: seg = 7'b1011011;
      4'h6: seg = 7'b1011111;
      4'h7: seg = 7'b1110000;
      4'h8: seg = 7'b1111111;
      4'h9: seg = 7'b1111011;
      4'hA: seg = 7'b1110111;
      4'hB: seg = 7'b0011111;
      4'hC: seg = 7'b1001110;
      4'hD: seg = 7'b0111101;
      4'hE: seg = 7'b1001111;
      default: seg = 7'b1000111;
    endcase
  end
  assign {seg1,seg2,seg3,seg4,seg5,seg6,seg7} = seg;
endmodule

// ---------------- Instruction register + control unit ----------------
// port order: clk, rst, z, common_bus, ir_in, ir_out, display_in, ram_in, ram_out,
//   mar_in, alu_out, sub, aout, bout, rega_in, regb_in, pc_out, pc_inc, pc_in, flags_in, halt
module controls(
  input clk,
  input rst,
  input z,
  inout [7:0] common_bus,
  output reg ir_in,
  output reg ir_out,
  output reg display_in,
  output reg ram_in,
  output reg ram_out,
  output reg mar_in,
  output reg alu_out,
  output reg sub,
  output reg aout,
  output reg bout,
  output reg rega_in,
  output reg regb_in,
  output reg pc_out,
  output reg pc_inc,
  output reg pc_in,
  output reg flags_in,
  output reg halt
);
  // Opcodes (top 4 bits of the instruction):
  //   0 = LDA   1 = ADD   2 = SUB   3 = STA   4 = LDI
  //   5 = JMP   6 = BEQ   7 = OUT   F = HLT

  reg [7:0] ir;              // instruction register
  reg [2:0] step;            // which step of the instruction we are on
  reg last;                  // 1 = this is the last step, go back to step 0
  wire [3:0] opcode = ir[7:4];

  always @(posedge clk) begin
    if (rst) ir <= 0;
    else if (ir_in) ir <= common_bus;
  end
  assign common_bus = ir_out ? {4'b0, ir[3:0]} : 8'bz;

  always @(posedge clk) begin
    if (rst) step <= 0;
    else if (!halt) begin
      if (last) step <= 0;
      else step <= step + 1;
    end
  end

  always @(*) begin
    // everything off by default
    ir_in=0; ir_out=0; display_in=0; ram_in=0; ram_out=0; mar_in=0;
    alu_out=0; sub=0; aout=0; bout=0; rega_in=0; regb_in=0; pc_out=0;
    pc_inc=0; pc_in=0; flags_in=0; halt=0; last=0;

    if (step == 0) begin                 // FETCH part 1
      pc_out=1; mar_in=1;
    end
    else if (step == 1) begin            // FETCH part 2
      ram_out=1; ir_in=1; pc_inc=1;
    end
    else begin                           // EXECUTE (depends on opcode)
      case (opcode)
        4'h0: begin                      // LDA
          if (step == 2) begin ir_out=1; mar_in=1; end
          if (step == 3) begin ram_out=1; rega_in=1; last=1; end
        end
        4'h1: begin                      // ADD
          if (step == 2) begin ir_out=1; mar_in=1; end
          if (step == 3) begin ram_out=1; regb_in=1; end
          if (step == 4) begin alu_out=1; rega_in=1; flags_in=1; last=1; end
        end
        4'h2: begin                      // SUB
          if (step == 2) begin ir_out=1; mar_in=1; end
          if (step == 3) begin ram_out=1; regb_in=1; end
          if (step == 4) begin sub=1; alu_out=1; rega_in=1; flags_in=1; last=1; end
        end
        4'h3: begin                      // STA
          if (step == 2) begin ir_out=1; mar_in=1; end
          if (step == 3) begin aout=1; ram_in=1; last=1; end
        end
        4'h4: begin                      // LDI
          ir_out=1; rega_in=1; last=1;
        end
        4'h5: begin                      // JMP
          ir_out=1; pc_in=1; last=1;
        end
        4'h6: begin                      // BEQ (jump only if zero flag is 1)
          ir_out=z; pc_in=z; last=1;
        end
        4'h7: begin                      // OUT
          aout=1; display_in=1; last=1;
        end
        4'hF: begin                      // HLT
          halt=1;
        end
        default: last=1;                 // unknown instruction, skip
      endcase
    end
  end
endmodule
// port order: clk, rst, seg1..seg7, shown, halt
module computer(
  input clk,
  input rst,
  output seg1,
  output seg2,
  output seg3,
  output seg4,
  output seg5,
  output seg6,
  output seg7,
  output [3:0] shown,
  output halt
);
  wire [7:0] common_bus;               // commonn bus
  wire [3:0] select;
  wire [7:0] alu_from_a, alu_from_b, aluout;
  wire z, c;
  wire ir_in, ir_out, display_in, ram_in, ram_out, mar_in, alu_out, sub;
  wire aout, bout, rega_in, regb_in, pc_out, pc_inc, pc_in, flags_in;

  //                  mar_in, clk, adress,           ram_in, ram_out, common_bus, select
  memory_adress_reg mar1(mar_in, clk, common_bus[3:0], ram_in, ram_out, common_bus, select);

  //      pc_inc, pc_in, pc_out, clk, rst, common_bus
  pc pc1(pc_inc, pc_in, pc_out, clk, rst, common_bus);

  //             common_bus, rega_in, regb_in, rega_out, regb_out, clk, alu_from_a, alu_from_b
  registers regs1(common_bus, rega_in, regb_in, aout,     bout,     clk, alu_from_a, alu_from_b);

  //      a,          b,          alu_out, sub, flags_in, clk, common_bus, aluout, z, c
  alu alu1(alu_from_a, alu_from_b, alu_out, sub, flags_in, clk, common_bus, aluout, z, c);

  //                         common_bus, display_in, clk, rst, seg1..seg7, shown
  display_from_0_to7 disp1(common_bus, display_in, clk, rst, seg1, seg2, seg3, seg4, seg5, seg6, seg7, shown);

  //            clk, rst, z, common_bus, ir_in, ir_out, display_in, ram_in, ram_out, mar_in,
  //            alu_out, sub, aout, bout, rega_in, regb_in, pc_out, pc_inc, pc_in, flags_in, halt
  controls ctrl1(clk, rst, z, common_bus, ir_in, ir_out, display_in, ram_in, ram_out, mar_in,
                 alu_out, sub, aout, bout, rega_in, regb_in, pc_out, pc_inc, pc_in, flags_in, halt);
endmodule
