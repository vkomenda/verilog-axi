// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 lite Man-in-the-middle (read)
 */
module axil_mitm_rd #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of interface data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of interface wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]               s_axil_arprot,
    input  wire                     s_axil_arvalid,
    output wire                     s_axil_arready,
    output wire [DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]               s_axil_rresp,
    output wire                     s_axil_rvalid,
    input  wire                     s_axil_rready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_araddr,
    output wire [2:0]               m_axil_arprot,
    output wire                     m_axil_arvalid,
    input  wire                     m_axil_arready,
    input  wire [DATA_WIDTH-1:0]    m_axil_rdata,
    input  wire [1:0]               m_axil_rresp,
    input  wire                     m_axil_rvalid,
    output wire                     m_axil_rready
);

// bus width assertions
localparam [1:0]
    STATE_IDLE = 2'b01,
    STATE_DATA = 2'b10;

/*
 * AXI lite internal interface
 */
wire [ADDR_WIDTH-1:0]    i_axil_araddr;
wire [2:0]               i_axil_arprot;
wire                     i_axil_arvalid;
wire                     i_axil_arready;
wire [DATA_WIDTH-1:0]    i_axil_rdata;
wire [1:0]               i_axil_rresp;
wire                     i_axil_rvalid;
wire                     i_axil_rready;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg [1:0] s_axil_rresp_reg = 2'd0, s_axil_rresp_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

reg [ADDR_WIDTH-1:0] i_axil_araddr_reg = {ADDR_WIDTH{1'b0}}, i_axil_araddr_next;
reg [2:0] i_axil_arprot_reg = 3'd0, i_axil_arprot_next;
reg i_axil_arvalid_reg = 1'b0, i_axil_arvalid_next;
reg i_axil_rready_reg = 1'b0, i_axil_rready_next;

assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign i_axil_araddr = i_axil_araddr_reg;
assign i_axil_arprot = i_axil_arprot_reg;
assign i_axil_arvalid = i_axil_arvalid_reg;
assign i_axil_rready = i_axil_rready_reg;

always @* begin
    state_next = STATE_IDLE;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rresp_next = s_axil_rresp_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;
    i_axil_araddr_next = i_axil_araddr_reg;
    i_axil_arprot_next = i_axil_arprot_reg;
    i_axil_arvalid_next = i_axil_arvalid_reg && !i_axil_arready;
    i_axil_rready_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            s_axil_arready_next = !i_axil_arvalid;

            if (s_axil_arready && s_axil_arvalid) begin
                s_axil_arready_next = 1'b0;
                i_axil_araddr_next = s_axil_araddr;
                i_axil_arprot_next = s_axil_arprot;
                i_axil_arvalid_next = 1'b1;
                i_axil_rready_next = !i_axil_rvalid;
                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DATA: begin
            i_axil_rready_next = !s_axil_rvalid;

            if (i_axil_rready && i_axil_rvalid) begin
                i_axil_rready_next = 1'b0;
                s_axil_rdata_next = i_axil_rdata;
                s_axil_rresp_next = i_axil_rresp;
                s_axil_rvalid_next = 1'b1;
                s_axil_arready_next = !i_axil_arvalid;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_DATA;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rresp_reg <= s_axil_rresp_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    i_axil_araddr_reg <= i_axil_araddr_next;
    i_axil_arprot_reg <= i_axil_arprot_next;
    i_axil_arvalid_reg <= i_axil_arvalid_next;
    i_axil_rready_reg <= i_axil_rready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        i_axil_arvalid_reg <= 1'b0;
        i_axil_rready_reg <= 1'b0;
    end
end // always @ (posedge clk)

// M side register
axil_register_rd #
(
 .DATA_WIDTH(DATA_WIDTH),
 .ADDR_WIDTH(ADDR_WIDTH),
 .STRB_WIDTH(STRB_WIDTH),
 .AR_REG_TYPE(2'd1),       // 1 = simple bypass buffer
 .R_REG_TYPE(2'd0)         // 0 = bypass
)
reg_inst
(
 .clk(clk),
 .rst(rst),
 .s_axil_araddr(i_axil_araddr),
 .s_axil_arprot(i_axil_arprot),
 .s_axil_arvalid(i_axil_arvalid),
 .s_axil_arready(i_axil_arready),
 .s_axil_rdata(i_axil_rdata),
 .s_axil_rresp(i_axil_rresp),
 .s_axil_rvalid(i_axil_rvalid),
 .s_axil_rready(i_axil_rready),
 .m_axil_araddr(m_axil_araddr),
 .m_axil_arprot(m_axil_arprot),
 .m_axil_arvalid(m_axil_arvalid),
 .m_axil_arready(m_axil_arready),
 .m_axil_rdata(m_axil_rdata),
 .m_axil_rresp(m_axil_rresp),
 .m_axil_rvalid(m_axil_rvalid),
 .m_axil_rready(m_axil_rready)
);

endmodule

`resetall
