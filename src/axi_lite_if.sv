/*********************************************************************************
** File Name   : axi_lite_if.sv
** Authors     : Group 4(Sajida Sayyad,Nikhil Swarna,Hanisha Dhananjaya Produttur,Venkat Sai Sumanth Koyada)
** Primary     : Sajida Sayyad
** Project     : AXI4 Lite Protocol
** Course      : ECE-571 Introduction to system verilog
**
** Description :
** ------------------------------------------------------------------------------
** This file defines the SystemVerilog interface for the AXI4-Lite protocol,
** encapsulating all five channels: Write Address (AW), Write Data (W),
** Write Response (B), Read Address (AR), and Read Data (R).
**
** Two modports are defined:
**  - master_mp : Drives address/data/control signals, receives readys & responses
**  - slave_mp  : Receives address/data/control signals, drives readys & responses
**
** Signal widths are parameterized through the axi_lite_pkg package.
**
** Created    : 02/24/26
** Last Edit  : 03/16/26
*********************************************************************************/
import axi_lite_pkg::*;

interface axi_lite_if (input logic clk, input logic rst_n);

  // Write Address channel
  logic [ADDR_W-1:0] awaddr;
  logic [2:0]        awprot;
  logic              awvalid;
  logic              awready;

  // Write Data channel
  logic [DATA_W-1:0] wdata;
  logic [STRB_W-1:0] wstrb;
  logic              wvalid;
  logic              wready;

  // Write Response channel
  axi_resp_t         bresp;
  logic              bvalid;
  logic              bready;

  // Read Address channel
  logic [ADDR_W-1:0] araddr;
  logic [2:0]        arprot;
  logic              arvalid;
  logic              arready;

  // Read Data channel
  logic [DATA_W-1:0] rdata;
  axi_resp_t         rresp;
  logic              rvalid;
  logic              rready;

  // Master drives outputs; receives readys + responses
  modport master_mp (
    input  clk, rst_n,
    output awaddr, awprot, awvalid,
    input  awready,
    output wdata, wstrb, wvalid,
    input  wready,
    input  bresp, bvalid,
    output bready,
    output araddr, arprot, arvalid,
    input  arready,
    input  rdata, rresp, rvalid,
    output rready
  );

  // Slave receives commands; drives readys + data + responses
  modport slave_mp (
    input  clk, rst_n,
    input  awaddr, awprot, awvalid,
    output awready,
    input  wdata, wstrb, wvalid,
    output wready,
    output bresp, bvalid,
    input  bready,
    input  araddr, arprot, arvalid,
    output arready,
    output rdata, rresp, rvalid,
    input  rready
  );

endinterface
