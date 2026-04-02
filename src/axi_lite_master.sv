/*********************************************************************************
** File Name   : axi_lite_master.sv
** Authors     : Group 4(Sajida Sayyad,Nikhil Swarna,Hanisha Dhananjaya Produttur,Venkat Sai Sumanth Koyada)
** Primary     : Nikhil Swarna & Venkat Sai Sumanth Koyada
** Project     : AXI4 Lite Protocol
** Course      : ECE-571 Introduction to system verilog
**
** Description :
** ------------------------------------------------------------------------------
** This package defines the axi_lite_master_bfm class, a Bus Functional Model
** that drives AXI4-Lite master transactions through the virtual interface (vif).
**
** Key Tasks:
**  - write()       : Drives AW and W channels simultaneously, waits for
**                    handshakes on awvalid/awready and wvalid/wready using
**                    parallel fork-join, then captures bresp from B channel
**  - read()        : Drives AR channel, waits for arvalid/arready handshake,
**                    then captures rdata and rresp from R channel
**  - multi_write() : Executes N sequential write transactions using wr_req_t
**                    struct array, returning an array of axi_resp_t responses
**  - multi_read()  : Executes N sequential read transactions from an address
**                    array, returning data and axi_resp_t response arrays
**
** All tasks are automatic and handshake-compliant — valid signals are
** deasserted only after the corresponding ready is observed on the rising
** clock edge, ensuring AXI4-Lite protocol correctness.
**
** Created    : 02/26/26
** Last Edit  : 03/12/26
*********************************************************************************/
package axi_lite_master_pkg;
import axi_lite_pkg::*;

class axi_lite_master_bfm;

  virtual axi_lite_if vif;

  //constructor
  function new(virtual axi_lite_if vif);
    this.vif = vif;
  endfunction

  //single write
  task automatic write(
    input  logic [ADDR_W-1:0] addr,
    input  logic [DATA_W-1:0] data,
    input  logic [STRB_W-1:0] strb = '1,
    output axi_resp_t          resp
  );
    // drive AW and W together on the next rising edge
    @(posedge vif.clk);
    vif.awaddr  <= addr;
    vif.awprot  <= 3'b000;
    vif.awvalid <= 1'b1;
    vif.wdata   <= data;
    vif.wstrb   <= strb;
    vif.wvalid  <= 1'b1;
    vif.bready  <= 1'b1;

    // wait for AW handshake  (valid must not drop until ready seen)
    fork
      begin
        do @(posedge vif.clk); while (!(vif.awvalid && vif.awready));
        vif.awvalid <= 1'b0;
      end
      begin
        do @(posedge vif.clk); while (!(vif.wvalid && vif.wready));
        vif.wvalid <= 1'b0;
      end
    join

    // wait for B response
    do @(posedge vif.clk); while (!(vif.bvalid && vif.bready));
    resp        = vif.bresp;
    vif.bready <= 1'b0;
  endtask

  // single read
  task automatic read(
    input  logic [ADDR_W-1:0] addr,
    output logic [DATA_W-1:0] data,
    output axi_resp_t          resp
  );
    @(posedge vif.clk);
    vif.araddr  <= addr;
    vif.arprot  <= 3'b000;
    vif.arvalid <= 1'b1;
    vif.rready  <= 1'b1;

    // wait for AR handshake
    do @(posedge vif.clk); while (!(vif.arvalid && vif.arready));
    vif.arvalid <= 1'b0;

    // wait for R data
    do @(posedge vif.clk); while (!(vif.rvalid && vif.rready));
    data        = vif.rdata;
    resp        = vif.rresp;
    vif.rready <= 1'b0;
  endtask

  // multi write: N independent single-beat transactions
  task automatic multi_write(
    input  wr_req_t    reqs[],
    output axi_resp_t  resps[]
  );
    resps = new[reqs.size()];
    foreach (reqs[i])
      write(reqs[i].addr, reqs[i].data, reqs[i].strb, resps[i]);
  endtask

  //multi read: N independent single-beat transactions
  task automatic multi_read(
    input  logic [ADDR_W-1:0] addrs[],
    output logic [DATA_W-1:0] datas[],
    output axi_resp_t          resps[]
  );
    datas = new[addrs.size()];
    resps = new[addrs.size()];
    foreach (addrs[i])
      read(addrs[i], datas[i], resps[i]);
  endtask

endclass

endpackage
