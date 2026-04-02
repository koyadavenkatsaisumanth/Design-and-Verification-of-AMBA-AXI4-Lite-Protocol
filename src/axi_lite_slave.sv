/*********************************************************************************
** File Name   : axi_lite_slave.sv
** Authors     : Group 4(Sajida Sayyad,Nikhil Swarna,Hanisha Dhananjaya Produttur,Venkat Sai Sumanth Koyada)
** Primary     : Hanisha Dhananjaya Produtur  & Venkat Sai Sumanth Koyada
** Project     : AXI4 Lite Protocol
** Course      : ECE-571 Introduction to system verilog
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
** Created    : 02/22/26
** Last Edit  : 03/12/26
*********************************************************************************/
import axi_lite_pkg::*;

module axi_lite_slave (axi_lite_if.slave_mp bus);

  localparam int NUM_REGS    = 8;
  localparam int RO_IDX      = 7;              // reg[7] is read-only
  localparam logic [ADDR_W-1:0] ADDR_MAX = 32'h1C;

  logic [DATA_W-1:0] regfile [NUM_REGS];
  logic              written [NUM_REGS];

  // address checks
  function automatic logic addr_inrange(input logic [ADDR_W-1:0] a);
    return (a <= ADDR_MAX) && (a[1:0] == 2'b00);
  endfunction

  function automatic logic addr_readonly(input logic [ADDR_W-1:0] a);
    return addr_inrange(a) && (addr_to_idx(a) == RO_IDX);
  endfunction

  // write path
  typedef enum logic [1:0] { WS_IDLE, WS_RESP } wr_st_t;
  wr_st_t wr_st;

  logic [ADDR_W-1:0] wr_addr_lat;
  logic [DATA_W-1:0] wr_data_lat;
  logic [STRB_W-1:0] wr_strb_lat;
  logic              aw_lat, w_lat;
  axi_resp_t         wr_resp_lat;

  always_ff @(posedge bus.clk or negedge bus.rst_n) begin
    if (!bus.rst_n) begin
      bus.awready <= 1'b1;   bus.wready  <= 1'b1;
      bus.bvalid  <= 1'b0;   bus.bresp   <= RESP_OKAY;
      aw_lat      <= 1'b0;   w_lat       <= 1'b0;
      wr_resp_lat <= RESP_OKAY;
      wr_st       <= WS_IDLE;
      for (int i = 0; i < NUM_REGS; i++) begin
        regfile[i] <= 32'hC0DE_0000 | i;  // pre-load so reads are interesting
        written[i] <= 1'b1;
      end
      regfile[RO_IDX] <= 32'hDEAD_BEEF;   // read-only reg has fixed value
    end else begin
      case (wr_st)

        WS_IDLE: begin
          // latch address
          if (bus.awvalid && bus.awready) begin
            wr_addr_lat <= bus.awaddr;
            aw_lat      <= 1'b1;
            bus.awready <= 1'b0;
            // decide response at address phase
            if (!addr_inrange(bus.awaddr))
              wr_resp_lat <= RESP_DECERR;
            else if (addr_readonly(bus.awaddr))
              wr_resp_lat <= RESP_SLVERR;
            else
              wr_resp_lat <= RESP_OKAY;
          end
          // latch data
          if (bus.wvalid && bus.wready) begin
            wr_data_lat <= bus.wdata;
            wr_strb_lat <= bus.wstrb;
            w_lat       <= 1'b1;
            bus.wready  <= 1'b0;
          end
          // both received then commit
          if ((aw_lat || (bus.awvalid && bus.awready)) &&
              (w_lat  || (bus.wvalid  && bus.wready ))) begin
            automatic logic [ADDR_W-1:0] a = aw_lat ? wr_addr_lat : bus.awaddr;
            automatic logic [DATA_W-1:0] d = w_lat  ? wr_data_lat : bus.wdata;
            automatic logic [STRB_W-1:0] s = w_lat  ? wr_strb_lat : bus.wstrb;
            automatic axi_resp_t         r = aw_lat  ? wr_resp_lat
                                             : (!addr_inrange(bus.awaddr) ? RESP_DECERR
                                                : addr_readonly(bus.awaddr) ? RESP_SLVERR
                                                : RESP_OKAY);
            bus.bresp  <= r;
            bus.bvalid <= 1'b1;
            if (r == RESP_OKAY) begin
              automatic int idx = addr_to_idx(a);
              regfile[idx] <= apply_strb(regfile[idx], d, s);
            end
            aw_lat      <= 1'b0;   w_lat <= 1'b0;
            wr_resp_lat <= RESP_OKAY;
            wr_st       <= WS_RESP;
          end
        end

        WS_RESP: begin
          if (bus.bvalid && bus.bready) begin
            bus.bvalid  <= 1'b0;
            bus.awready <= 1'b1;   bus.wready <= 1'b1;
            wr_st       <= WS_IDLE;
          end
        end

        default: wr_st <= WS_IDLE;
      endcase
    end
  end

  // read path
  typedef enum logic [1:0] { RS_IDLE, RS_DATA } rd_st_t;
  rd_st_t rd_st;

  always_ff @(posedge bus.clk or negedge bus.rst_n) begin
    if (!bus.rst_n) begin
      bus.arready <= 1'b1;   bus.rvalid <= 1'b0;
      bus.rdata   <= '0;     bus.rresp  <= RESP_OKAY;
      rd_st       <= RS_IDLE;
    end else begin
      case (rd_st)
        RS_IDLE: begin
          if (bus.arvalid && bus.arready) begin
            bus.arready <= 1'b0;
            if (!addr_inrange(bus.araddr)) begin
              bus.rdata  <= '0;
              bus.rresp  <= RESP_DECERR;
            end else begin
              // read-only register is readable by anyone then OKAY
              bus.rdata  <= regfile[addr_to_idx(bus.araddr)];
              bus.rresp  <= RESP_OKAY;
            end
            bus.rvalid <= 1'b1;
            rd_st      <= RS_DATA;
          end
        end
        RS_DATA: begin
          if (bus.rvalid && bus.rready) begin
            bus.rvalid  <= 1'b0;   bus.arready <= 1'b1;
            rd_st       <= RS_IDLE;
          end
        end
        default: rd_st <= RS_IDLE;
      endcase
    end
  end

endmodule
