/*********************************************************************************
** File Name   : tb_axi_lite.sv
** Author      : Venkat Sai Sumanth Koyada & Sajida Sayyad
** Project     : AXI4 Lite Protocol
** Course      : ECE-571 Introduction to System Verilog
**
** Description :
** ------------------------------------------------------------------------------
** This module implements an AXI4-Lite slave with an 8-register file (reg[0]..reg[7])
** connected via the slave_mp modport. reg[7] is read-only (0xDEAD_BEEF);
** reg[0]..reg[6] are read-write (pre-loaded with 0xC0DE_000x).
**
** Response Rules:
**  - RESP_OKAY   : Valid aligned address to a writable register
**  - RESP_SLVERR : Write attempted on read-only reg[7]
**  - RESP_DECERR : Address out of range (> 0x1C) or misaligned (addr[1:0] != 00)
**
** Write path (WS_IDLE → WS_RESP) latches AW and W channels independently,
** commits to regfile via apply_strb(), then issues bresp on B channel.
** Read path (RS_IDLE → RS_DATA) captures araddr, drives rdata and rresp on R channel.
**
** Created    : 02/24/26
** Last Edit  : 03/10/26
*********************************************************************************/
`timescale 1ns/1ps
import axi_lite_pkg::*;
import axi_lite_master_pkg::*;

module tb_axi_lite;

  // clock & reset
  logic clk   = 0;
  logic rst_n = 0;
  always #5 clk = ~clk;

  // DUT
  axi_lite_if         bus (.clk(clk), .rst_n(rst_n));
  axi_lite_slave      dut (.bus(bus));
  axi_lite_master_bfm master;

  // pass / fail counters (simple, no scoreboard struct)
  int pass_cnt = 0;
  int fail_cnt = 0;

  // response to string
  function automatic string resp_str(input axi_resp_t r);
    case (r)
      RESP_OKAY:   return "OKAY  ";
      RESP_SLVERR: return "SLVERR";
      RESP_DECERR: return "DECERR";
      default:     return "??????";
    endcase
  endfunction

  // PRINT HELPERS
  

  localparam string DIV =
    "  ------ --------- ----------  ----------   ------   ------   -------------------------";

  task print_header();
    $display("  %-6s %-9s %-10s  %-10s   %-6s   %-6s   %s",
             "STEP", "OP", "ADDR", "DATA", "RESP", "RESULT", "NOTE");
    $display(DIV);
  endtask

  task print_section(input string title, input string desc);
    $display("");
    $display("  %s", title);
    $display("  %s", desc);
    $display("");
    print_header();
  endtask

  // write and print
  task automatic do_write(
    input string              step,
    input logic [ADDR_W-1:0]  addr,
    input logic [DATA_W-1:0]  data,
    input logic [STRB_W-1:0]  strb,
    input axi_resp_t           exp_resp
  );
    axi_resp_t got_resp;
    string     result;
    master.write(addr, data, strb, got_resp);
    result = (got_resp === exp_resp) ? "PASS" : "FAIL";
    if (got_resp === exp_resp) pass_cnt++; else fail_cnt++;
    $display("  %-6s %-9s 0x%08h  0x%08h   %-6s   %-6s   exp=%s",
             step, "WRITE", addr, data,
             resp_str(got_resp), result, resp_str(exp_resp));
  endtask

  // read and print
  task automatic do_read(
    input  string              step,
    input  logic [ADDR_W-1:0]  addr,
    input  logic [DATA_W-1:0]  exp_data,
    input  axi_resp_t           exp_resp,
    output logic [DATA_W-1:0]  got_data
  );
    axi_resp_t got_resp;
    string     result;
    master.read(addr, got_data, got_resp);
    result = ((got_data === exp_data) && (got_resp === exp_resp)) ? "PASS" : "FAIL";
    if (result == "PASS") pass_cnt++; else fail_cnt++;
    $display("  %-6s %-9s 0x%08h  0x%08h   %-6s   %-6s   exp_data=0x%08h  exp_resp=%s",
             step, "READ", addr, got_data,
             resp_str(got_resp), result, exp_data, resp_str(exp_resp));
  endtask

  // print divider between sections
  task print_div();
    $display(DIV);
  endtask

  // VCD
  initial begin
    $dumpfile("axi_lite_waves.vcd");
    $dumpvars(0, tb_axi_lite);
  end

  // MAIN TEST SEQUENCE
  initial begin
    logic [DATA_W-1:0] rdata;

    bus.awvalid=0; bus.awaddr=0; bus.awprot=0;
    bus.wvalid=0;  bus.wdata=0;  bus.wstrb=0;  bus.bready=0;
    bus.arvalid=0; bus.araddr=0; bus.arprot=0; bus.rready=0;

    master = new(bus);
    repeat(3) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);

    // banner
    $display("");
    $display("  ============================================================");
    $display("  AXI-LITE RESPONSE CODE TESTBENCH");
    $display("  Covers: OKAY  |  SLVERR  |  DECERR  +  normal operations");
    $display("  reg[7] addr=0x1C is READ-ONLY  (write -> SLVERR)");
    $display("  ============================================================");
/*
    // SECTION 1:  OKAY  —  normal valid transactions
    print_section(
      "SECTION 1   OKAY  —  normal read and write",
      "All addresses valid, all registers writable  ->  every resp = OKAY"
    );

    // write four registers
    do_write("W1",  32'h00, 32'hAAAA_1111, 4'hF, RESP_OKAY);
    do_write("W2",  32'h04, 32'hBBBB_2222, 4'hF, RESP_OKAY);
    do_write("W3",  32'h08, 32'hCCCC_3333, 4'hF, RESP_OKAY);
    do_write("W4",  32'h0C, 32'hDDDD_4444, 4'hF, RESP_OKAY);

    // read them back immediately
    do_read ("R1",  32'h00, 32'hAAAA_1111, RESP_OKAY, rdata);
    do_read ("R2",  32'h04, 32'hBBBB_2222, RESP_OKAY, rdata);
    do_read ("R3",  32'h08, 32'hCCCC_3333, RESP_OKAY, rdata);
    do_read ("R4",  32'h0C, 32'hDDDD_4444, RESP_OKAY, rdata);

    // partial strobe write then read back  (also OKAY)
    do_write("W5",  32'h00, 32'hFFFF_FFFF, 4'h3, RESP_OKAY);
    do_read ("R5",  32'h00, 32'hAAAA_FFFF, RESP_OKAY, rdata);

    // overwrite and confirm
    do_write("W6",  32'h00, 32'h1234_5678, 4'hF, RESP_OKAY);
    do_read ("R6",  32'h00, 32'h1234_5678, RESP_OKAY, rdata);

    // read read-only reg[7] (reading is allowed -> OKAY)
    do_read ("R7",  32'h1C, 32'hDEAD_BEEF, RESP_OKAY, rdata);

    print_div();

    // SECTION 2:  SLVERR 
    print_section(
      "SECTION 2   SLVERR  —  write to read-only register",
      "reg[7] addr=0x1C is protected  ->  write returns SLVERR  read still OKAY"
    );

    // attempt to write read-only reg -> SLVERR
    do_write("W1",  32'h1C, 32'hDEAD_0000, 4'hF, RESP_SLVERR);

    // confirm reg[7] value is unchanged after failed write
    do_read ("R1",  32'h1C, 32'hDEAD_BEEF, RESP_OKAY, rdata);

    // write with partial strobe -> still SLVERR
    do_write("W2",  32'h1C, 32'hFFFF_FFFF, 4'h3, RESP_SLVERR);
    do_read ("R2",  32'h1C, 32'hDEAD_BEEF, RESP_OKAY, rdata);

    // write with zero strobe -> still SLVERR (address is checked first)
    do_write("W3",  32'h1C, 32'h0000_0000, 4'h0, RESP_SLVERR);
    do_read ("R3",  32'h1C, 32'hDEAD_BEEF, RESP_OKAY, rdata);

    // normal write to adjacent reg[6] -> OKAY (bus recovered)
    do_write("W4",  32'h18, 32'hBEEF_CAFE, 4'hF, RESP_OKAY);
    do_read ("R4",  32'h18, 32'hBEEF_CAFE, RESP_OKAY, rdata);

    print_div();

    // SECTION 3:  DECERR 
    print_section(
      "SECTION 3   DECERR  —  invalid addresses",
      "Out-of-range or misaligned access  ->  DECERR  no register touched"
    );

    // out-of-range write
    do_write("W1",  32'hFF,   32'hBAD0_0001, 4'hF, RESP_DECERR);
    do_write("W2",  32'hABCD, 32'hBAD0_0002, 4'hF, RESP_DECERR);

    // out-of-range read  (rdata must come back 0x0)
    do_read ("R1",  32'hFF,   32'h0000_0000, RESP_DECERR, rdata);
    do_read ("R2",  32'hABCD, 32'h0000_0000, RESP_DECERR, rdata);

    // misaligned write  (addr[1:0] != 00)
    do_write("W3",  32'h01,   32'hBAD0_0003, 4'hF, RESP_DECERR);
    do_write("W4",  32'h02,   32'hBAD0_0004, 4'hF, RESP_DECERR);
    do_write("W5",  32'h03,   32'hBAD0_0005, 4'hF, RESP_DECERR);

    // misaligned read
    do_read ("R3",  32'h01,   32'h0000_0000, RESP_DECERR, rdata);
    do_read ("R4",  32'h03,   32'h0000_0000, RESP_DECERR, rdata);

    // confirm reg[0] is untouched after all DECERR writes
    do_read ("R5",  32'h00,   32'h1234_5678, RESP_OKAY,   rdata);

    print_div();
*/
    // SECTION 4:  MIXED  —  all three responses in one sequence
    print_section(
      "SECTION 4   MIXED  —  OKAY + SLVERR + DECERR interleaved",
      "Real-world mix: valid ops, protected reg writes, bad addresses"
    );

    // valid write
    do_write("W1",  32'h10, 32'hFACE_0001, 4'hF, RESP_OKAY);

    // bad address write -> DECERR
    do_write("W2",  32'hFF, 32'hBAD0_0006, 4'hF, RESP_DECERR);

    // read-only write -> SLVERR
    do_write("W3",  32'h1C, 32'hBAD0_0007, 4'hF, RESP_SLVERR);

    // valid read after two errors
    do_read ("R1",  32'h10, 32'hFACE_0001, RESP_OKAY,   rdata);

    // read protected reg (allowed)
    do_read ("R2",  32'h1C, 32'hDEAD_BEEF, RESP_OKAY,   rdata);

    // OOR read
    do_read ("R3",  32'hFF, 32'h0000_0000, RESP_DECERR, rdata);

    // valid write after all errors -> bus must be healthy
    do_write("W4",  32'h14, 32'hCAFE_BABE, 4'hF, RESP_OKAY);
    do_read ("R4",  32'h14, 32'hCAFE_BABE, RESP_OKAY,   rdata);

    // misaligned then valid
    do_write("W5",  32'h02, 32'hBAD0_0008, 4'hF, RESP_DECERR);
    do_write("W6",  32'h04, 32'hBEEF_1234, 4'hF, RESP_OKAY);
    do_read ("R5",  32'h04, 32'hBEEF_1234, RESP_OKAY,   rdata);

    print_div();

    // final summary
    $display("");
    $display("  ============================================================");
    $display("  SUMMARY");
    $display("  ============================================================");
    $display("  Total checks   %0d", pass_cnt + fail_cnt);
    $display("  PASS           %0d", pass_cnt);
    $display("  FAIL           %0d", fail_cnt);
    $display("");
    if (fail_cnt == 0)
      $display("  ALL CHECKS PASSED");
    else
      $display("  %0d FAILURE(S) DETECTED  <<<", fail_cnt);
    $display("  ============================================================");
    $display("");

    $stop;
  end

  initial begin
    #300_000;
    $display("  WATCHDOG  timeout  simulation killed");
    $stop;
  end

endmodule