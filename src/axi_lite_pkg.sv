/*********************************************************************************
** File Name   : axi_lite_pkg.sv
** Authors     : Group 4(Sajida Sayyad,Nikhil Swarna,Hanisha Dhananjaya Produttur,Venkat Sai Sumanth Koyada)
** Primary     : Sajida Sayyad
** Project     : AXI4 Lite Protocol
** Course      : ECE-571 Introduction to system verilog
**
** Description :
** ------------------------------------------------------------------------------
** This package defines shared parameters, types, and utility functions
** used across the AXI4-Lite verification environment.
**
** Contents:
**  - Parameters : ADDR_W (32), DATA_W (32), STRB_W (DATA_W/8)
**  - axi_resp_t : Enum for AXI response codes (OKAY, SLVERR, DECERR)
**  - wr_req_t   : Packed struct bundling write address, data, and strobe
**  - sb_entry_t : Struct for scoreboard comparison (expected vs actual data)
**  - apply_strb : Function to apply byte-lane write strobes to a data word
**  - addr_to_idx: Function to map a byte address to a register index (bits [4:2])
**
** Created    : 02/28/26
** Last Edit  : 03/14/26
*********************************************************************************/

package axi_lite_pkg;

  // parameters
  parameter int ADDR_W = 32;
  parameter int DATA_W = 32;
  parameter int STRB_W = DATA_W / 8;   // 4 byte lanes

  // AXI response enum
  typedef enum logic [1:0] {
    RESP_OKAY   = 2'b00,
    RESP_SLVERR = 2'b10,
    RESP_DECERR = 2'b11
  } axi_resp_t;

  // write request struct
  typedef struct packed {
    logic [ADDR_W-1:0] addr;
    logic [DATA_W-1:0] data;
    logic [STRB_W-1:0] strb;   // byte-enable: 1 bit per byte lane
  } wr_req_t;

  // scoreboard entry struct
  typedef struct {
    logic [ADDR_W-1:0] addr;
    logic [DATA_W-1:0] exp_data;
    logic [DATA_W-1:0] got_data;
    logic              pass;
  } sb_entry_t;

  // apply strobe mask
  // only writes bytes whose strobe bit is 1
  function automatic logic [DATA_W-1:0] apply_strb(
    input logic [DATA_W-1:0] old_val,
    input logic [DATA_W-1:0] new_val,
    input logic [STRB_W-1:0] strb
  );
    logic [DATA_W-1:0] result;
    for (int b = 0; b < STRB_W; b++)
      result[b*8 +: 8] = strb[b] ? new_val[b*8 +: 8] : old_val[b*8 +: 8];
    return result;
  endfunction

  //byte address → register index
  function automatic int addr_to_idx(input logic [ADDR_W-1:0] addr);
    return int'(addr[4:2]);   // bits [4:2] → 0..7
  endfunction

endpackage
