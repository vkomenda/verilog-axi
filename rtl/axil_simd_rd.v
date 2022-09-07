// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 lite Man-in-the-middle (read)
 */
module axil_simd_rd #
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
    output wire [M_COUNT*ADDR_WIDTH-1:0]  m_axil_araddr,
    output wire [M_COUNT*3-1:0]           m_axil_arprot,
    output wire [M_COUNT-1:0]             m_axil_arvalid,
    input  wire [M_COUNT-1:0]             m_axil_arready,
    input  wire [M_COUNT*DATA_WIDTH-1:0]  m_axil_rdata,
    input  wire [M_COUNT*2-1:0]           m_axil_rresp,
    input  wire [M_COUNT-1:0]             m_axil_rvalid,
    output wire [M_COUNT-1:0]             m_axil_rready
);

// bus width assertions
localparam [1:0]
    STATE_IDLE = 2'b01,
    STATE_DATA = 2'b10;

localparam
    STATE_IDLE_ID = 0,
    STATE_DATA_ID = 1;

// Aggregate signals
wire none_m_axil_arvalid = ~|m_axil_arvalid;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [DATA_WIDTH-1:0] s_axil_rdata_reg = {DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg [1:0] s_axil_rresp_reg = 2'd0, s_axil_rresp_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

// Local araddr and arprot storage to reduce fanout of slave input nets.
reg [M_COUNT*ADDR_WIDTH-1:0] m_axil_araddr_reg = {M_COUNT*ADDR_WIDTH{1'b0}}, m_axil_araddr_next;
reg [M_COUNT*3-1:0] m_axil_arprot_reg = {M_COUNT{3'd0}}, m_axil_arprot_next;
reg [M_COUNT-1:0] m_axil_arvalid_reg = {M_COUNT{1'b0}}, m_axil_arvalid_next;
reg [M_COUNT-1:0] m_axil_rready_reg = {M_COUNT{1'b0}}, m_axil_rready_next;

assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign m_axil_araddr = m_axil_araddr_reg;
assign m_axil_arprot = m_axil_arprot_reg;
assign m_axil_arvalid = m_axil_arvalid_reg;
assign m_axil_rready = m_axil_rready_reg;

always @* begin
    state_next = STATE_IDLE;

    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rresp_next = s_axil_rresp_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg & ~s_axil_rready;
    m_axil_araddr_next = m_axil_araddr_reg;
    m_axil_arprot_next = m_axil_arprot_reg;
    m_axil_arvalid_next = m_axil_arvalid_reg & ~m_axil_arready;
    m_axil_rready_next = 1'b0;

    // one-hot next state and output logic
    case (1'b1)
        state_reg[STATE_IDLE_ID]: begin
            s_axil_arready_next = none_m_axil_arvalid;

            if (s_axil_arready && s_axil_arvalid) begin
                s_axil_arready_next = 1'b0;
                m_axil_araddr_next = {M_COUNT{s_axil_araddr}};
                m_axil_arprot_next = {M_COUNT{s_axil_arprot}};

                m_axil_arvalid_next = {M_COUNT{1'b1}};
                m_axil_rready_next = ~m_axil_rvalid;

                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end // case: state_reg[STATE_IDLE_ID]

        state_reg[STATE_DATA_ID]: begin
            m_axil_rready_next = {M_COUNT{~s_axil_rvalid}};

            if (&m_axil_rready && &m_axil_rvalid) begin
                m_axil_rready_next = {M_COUNT{1'b0}};
                s_axil_rdata_next = m_axil_rdata[DATA_WIDTH-1:0];
                s_axil_rresp_next = m_axil_rresp[1:0];
                s_axil_rvalid_next = 1'b1;
                s_axil_arready_next = none_m_axil_arvalid;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_DATA;
            end
        end // case: state_reg[STATE_DATA_ID]

        default:
            state_next = STATE_IDLE;
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rdata_reg <= s_axil_rdata_next;
    s_axil_rresp_reg <= s_axil_rresp_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    m_axil_araddr_reg <= m_axil_araddr_next;
    m_axil_arprot_reg <= m_axil_arprot_next;
    m_axil_arvalid_reg <= m_axil_arvalid_next;
    m_axil_rready_reg <= m_axil_rready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;
    end
end // always @ (posedge clk)

endmodule

`resetall
