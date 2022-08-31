// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 lite Man-in-the-middle (write)
 */
module axil_mitm_wr #
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
    input  wire [ADDR_WIDTH-1:0]    s_axil_awaddr,
    input  wire [2:0]               s_axil_awprot,
    input  wire                     s_axil_awvalid,
    output wire                     s_axil_awready,
    input  wire [DATA_WIDTH-1:0]    s_axil_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axil_wstrb,
    input  wire                     s_axil_wvalid,
    output wire                     s_axil_wready,
    output wire [1:0]               s_axil_bresp,
    output wire                     s_axil_bvalid,
    input  wire                     s_axil_bready,

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_awaddr,
    output wire [2:0]               m_axil_awprot,
    output wire                     m_axil_awvalid,
    input  wire                     m_axil_awready,
    output wire [DATA_WIDTH-1:0]    m_axil_wdata,
    output wire [STRB_WIDTH-1:0]    m_axil_wstrb,
    output wire                     m_axil_wvalid,
    input  wire                     m_axil_wready,
    input  wire [1:0]               m_axil_bresp,
    input  wire                     m_axil_bvalid,
    output wire                     m_axil_bready
);

localparam [2:0]
    STATE_IDLE = 3'b001,
    STATE_DATA = 3'b010,
    STATE_RESP = 3'b100;

/*
 * AXI lite internal interface
 */
wire [ADDR_WIDTH-1:0]    i_axil_awaddr;
wire [2:0]               i_axil_awprot;
wire                     i_axil_awvalid;
wire                     i_axil_awready;
wire [DATA_WIDTH-1:0]    i_axil_wdata;
wire [STRB_WIDTH-1:0]    i_axil_wstrb;
wire                     i_axil_wvalid;
wire                     i_axil_wready;
wire [1:0]               i_axil_bresp;
wire                     i_axil_bvalid;
wire                     i_axil_bready;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;
reg [STRB_WIDTH-1:0] strb_reg = {STRB_WIDTH{1'b0}}, strb_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg [1:0] s_axil_bresp_reg = 2'd0, s_axil_bresp_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

reg [ADDR_WIDTH-1:0] i_axil_awaddr_reg = {ADDR_WIDTH{1'b0}}, i_axil_awaddr_next;
reg [2:0] i_axil_awprot_reg = 3'd0, i_axil_awprot_next;
reg i_axil_awvalid_reg = 1'b0, i_axil_awvalid_next;
reg [DATA_WIDTH-1:0] i_axil_wdata_reg = {DATA_WIDTH{1'b0}}, i_axil_wdata_next;
reg [STRB_WIDTH-1:0] i_axil_wstrb_reg = {STRB_WIDTH{1'b0}}, i_axil_wstrb_next;
reg i_axil_wvalid_reg = 1'b0, i_axil_wvalid_next;
reg i_axil_bready_reg = 1'b0, i_axil_bready_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

assign i_axil_awaddr = i_axil_awaddr_reg;
assign i_axil_awprot = i_axil_awprot_reg;
assign i_axil_awvalid = i_axil_awvalid_reg;
assign i_axil_wdata = i_axil_wdata_reg;
assign i_axil_wstrb = i_axil_wstrb_reg;
assign i_axil_wvalid = i_axil_wvalid_reg;
assign i_axil_bready = i_axil_bready_reg;

always @* begin
    state_next = STATE_IDLE;

    data_next = data_reg;
    strb_next = strb_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bresp_next = s_axil_bresp_reg;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;
    i_axil_awaddr_next = i_axil_awaddr_reg;
    i_axil_awprot_next = i_axil_awprot_reg;
    i_axil_awvalid_next = i_axil_awvalid_reg && !i_axil_awready;
    i_axil_wdata_next = i_axil_wdata_reg;
    i_axil_wstrb_next = i_axil_wstrb_reg;
    i_axil_wvalid_next = i_axil_wvalid_reg && !i_axil_wready;
    i_axil_bready_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            s_axil_awready_next = !i_axil_awvalid;

            if (s_axil_awready && s_axil_awvalid) begin
                s_axil_awready_next = 1'b0;
                i_axil_awaddr_next = s_axil_awaddr;
                i_axil_awprot_next = s_axil_awprot;
                i_axil_awvalid_next = 1'b1;
                s_axil_wready_next = !i_axil_wvalid;
                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DATA: begin
            s_axil_wready_next = !i_axil_wvalid;

            if (s_axil_wready && s_axil_wvalid) begin
                s_axil_wready_next = 1'b0;
                i_axil_wdata_next = s_axil_wdata;
                i_axil_wstrb_next = s_axil_wstrb;
                i_axil_wvalid_next = 1'b1;
                i_axil_bready_next = !s_axil_bvalid;
                state_next = STATE_RESP;
            end else begin
                state_next = STATE_DATA;
            end
        end
        STATE_RESP: begin
            i_axil_bready_next = !s_axil_bvalid;

            if (i_axil_bready && i_axil_bvalid) begin
                i_axil_bready_next = 1'b0;
                s_axil_bresp_next = i_axil_bresp;
                s_axil_bvalid_next = 1'b1;
                s_axil_awready_next = !i_axil_awvalid;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_RESP;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    data_reg <= data_next;
    strb_reg <= strb_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bresp_reg <= s_axil_bresp_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    i_axil_awaddr_reg <= i_axil_awaddr_next;
    i_axil_awprot_reg <= i_axil_awprot_next;
    i_axil_awvalid_reg <= i_axil_awvalid_next;
    i_axil_wdata_reg <= i_axil_wdata_next;
    i_axil_wstrb_reg <= i_axil_wstrb_next;
    i_axil_wvalid_reg <= i_axil_wvalid_next;
    i_axil_bready_reg <= i_axil_bready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        i_axil_awvalid_reg <= 1'b0;
        i_axil_wvalid_reg <= 1'b0;
        i_axil_bready_reg <= 1'b0;
    end
end

// M side register
axil_register_wr #
(
 .DATA_WIDTH(DATA_WIDTH),
 .ADDR_WIDTH(ADDR_WIDTH),
 .STRB_WIDTH(STRB_WIDTH),
 .AW_REG_TYPE(2'd1),      // 1 = simple buffer
 .W_REG_TYPE(2'd2),       // 2 = skid buffer
 .B_REG_TYPE(2'd0)        // 0 = bypass
)
reg_inst
(
 .clk(clk),
 .rst(rst),
 .s_axil_awaddr(i_axil_awaddr),
 .s_axil_awprot(i_axil_awprot),
 .s_axil_awvalid(i_axil_awvalid),
 .s_axil_awready(i_axil_awready),
 .s_axil_wdata(i_axil_wdata),
 .s_axil_wstrb(i_axil_wstrb),
 .s_axil_wvalid(i_axil_wvalid),
 .s_axil_wready(i_axil_wready),
 .s_axil_bresp(i_axil_bresp),
 .s_axil_bvalid(i_axil_bvalid),
 .s_axil_bready(i_axil_bready),
 .m_axil_awaddr(m_axil_awaddr),
 .m_axil_awprot(m_axil_awprot),
 .m_axil_awvalid(m_axil_awvalid),
 .m_axil_awready(m_axil_awready),
 .m_axil_wdata(m_axil_wdata),
 .m_axil_wstrb(m_axil_wstrb),
 .m_axil_wvalid(m_axil_wvalid),
 .m_axil_wready(m_axil_wready),
 .m_axil_bresp(m_axil_bresp),
 .m_axil_bvalid(m_axil_bvalid),
 .m_axil_bready(m_axil_bready)
);

endmodule

`resetall
