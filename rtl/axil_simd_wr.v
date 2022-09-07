// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 lite Man-in-the-middle (write)
 */
module axil_simd_wr #
(
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 8,
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
    output wire [M_COUNT*ADDR_WIDTH-1:0]    m_axil_awaddr,
    output wire [M_COUNT*3-1:0]             m_axil_awprot,
    output wire [M_COUNT-1:0]               m_axil_awvalid,
    input  wire [M_COUNT-1:0]               m_axil_awready,
    output wire [M_COUNT*DATA_WIDTH-1:0]    m_axil_wdata,
    output wire [M_COUNT*STRB_WIDTH-1:0]    m_axil_wstrb,
    output wire [M_COUNT-1:0]               m_axil_wvalid,
    input  wire [M_COUNT-1:0]               m_axil_wready,
    input  wire [M_COUNT*2-1:0]             m_axil_bresp,
    input  wire [M_COUNT-1:0]               m_axil_bvalid,
    output wire [M_COUNT-1:0]               m_axil_bready
);

localparam [2:0]
    STATE_IDLE = 3'b001,
    STATE_DATA = 3'b010,
    STATE_RESP = 3'b100;

localparam
    STATE_IDLE_ID = 0,
    STATE_DATA_ID = 1,
    STATE_RESP_ID = 2;

reg [2:0] state_reg = STATE_IDLE, state_next;

reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;
reg [STRB_WIDTH-1:0] strb_reg = {STRB_WIDTH{1'b0}}, strb_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg [1:0] s_axil_bresp_reg = 2'd0, s_axil_bresp_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

reg [M_COUNT*ADDR_WIDTH-1:0] m_axil_awaddr_reg = {M_COUNT*ADDR_WIDTH{1'b0}}, m_axil_awaddr_next;
reg [M_COUNT*3-1:0] m_axil_awprot_reg = {M_COUNT{3'd0}}, m_axil_awprot_next;
reg [M_COUNT-1:0] m_axil_awvalid_reg = {M_COUNT{1'b0}}, m_axil_awvalid_next;
reg [M_COUNT*DATA_WIDTH-1:0] m_axil_wdata_reg = {M_COUNT*DATA_WIDTH{1'b0}}, m_axil_wdata_next;
reg [M_COUNT*STRB_WIDTH-1:0] m_axil_wstrb_reg = {M_COUNT*STRB_WIDTH{1'b0}}, m_axil_wstrb_next;
reg [M_COUNT-1:0] m_axil_wvalid_reg = {M_COUNT{1'b0}}, m_axil_wvalid_next;
reg [M_COUNT-1:0] m_axil_bready_reg = {M_COUNT{1'b0}}, m_axil_bready_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

assign m_axil_awaddr = m_axil_awaddr_reg;
assign m_axil_awprot = m_axil_awprot_reg;
assign m_axil_awvalid = m_axil_awvalid_reg;
assign m_axil_wdata = m_axil_wdata_reg;
assign m_axil_wstrb = m_axil_wstrb_reg;
assign m_axil_wvalid = m_axil_wvalid_reg;
assign m_axil_bready = m_axil_bready_reg;

always @* begin
    state_next = STATE_IDLE;

    data_next = data_reg;
    strb_next = strb_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bresp_next = s_axil_bresp_reg;
    s_axil_bvalid_next = s_axil_bvalid_reg & ~s_axil_bready;
    m_axil_awaddr_next = m_axil_awaddr_reg;
    m_axil_awprot_next = m_axil_awprot_reg;
    m_axil_awvalid_next = m_axil_awvalid_reg & ~m_axil_awready;
    m_axil_wdata_next = m_axil_wdata_reg;
    m_axil_wstrb_next = m_axil_wstrb_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg & ~m_axil_wready;
    m_axil_bready_next = {M_COUNT{1'b0}};

    case (1'b1)
        state_reg[STATE_IDLE_ID]: begin
            s_axil_awready_next = ~|m_axil_awvalid;

            if (s_axil_awready && s_axil_awvalid) begin
                s_axil_awready_next = 1'b0;
                m_axil_awaddr_next = {M_COUNT{s_axil_awaddr}};
                m_axil_awprot_next = {M_COUNT{s_axil_awprot}};
                m_axil_awvalid_next = {M_COUNT{1'b1}};
                s_axil_wready_next = ~|m_axil_wvalid;
                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end // case: state_reg[STATE_IDLE_ID]

        state_reg[STATE_DATA_ID]: begin
            s_axil_wready_next = ~|m_axil_wvalid;

            if (s_axil_wready && s_axil_wvalid) begin
                s_axil_wready_next = 1'b0;
                m_axil_wdata_next = {M_COUNT{s_axil_wdata}};
                m_axil_wstrb_next = {M_COUNT{s_axil_wstrb}};
                m_axil_wvalid_next = {M_COUNT{1'b1}};
                m_axil_bready_next = {M_COUNT{~s_axil_bvalid}};
                state_next = STATE_RESP;
            end else begin
                state_next = STATE_DATA;
            end
        end // case: state_reg[STATE_DATA_ID]

        state_reg[STATE_RESP_ID]: begin
            m_axil_bready_next = {M_COUNT{~s_axil_bvalid}};

            if (&m_axil_bready && &m_axil_bvalid) begin
                m_axil_bready_next = {M_COUNT{1'b0}};
                s_axil_bresp_next = m_axil_bresp[1:0];
                s_axil_bvalid_next = {M_COUNT{1'b1}};
                s_axil_awready_next = ~|m_axil_awvalid;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_RESP;
            end
        end // case: state_reg[STATE_RESP_ID]

        default: begin
            state_next = STATE_IDLE;
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

    m_axil_awaddr_reg <= m_axil_awaddr_next;
    m_axil_awprot_reg <= m_axil_awprot_next;
    m_axil_awvalid_reg <= m_axil_awvalid_next;
    m_axil_wdata_reg <= m_axil_wdata_next;
    m_axil_wstrb_reg <= m_axil_wstrb_next;
    m_axil_wvalid_reg <= m_axil_wvalid_next;
    m_axil_bready_reg <= m_axil_bready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        m_axil_awvalid_reg <= {M_COUNT{1'b0}};
        m_axil_wvalid_reg <= {M_COUNT{1'b0}};
        m_axil_bready_reg <= {M_COUNT{1'b0}};
    end
end

endmodule

`resetall
