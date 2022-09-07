#!/usr/bin/env python
"""
Generates an AXI lite simd wrapper with the specified number of ports
"""

import argparse
from jinja2 import Template


def main():
    parser = argparse.ArgumentParser(description=__doc__.strip())
    parser.add_argument('-p', '--ports',  type=int, default=[8], nargs='+', help="number of ports")
    parser.add_argument('-n', '--name',   type=str, help="module name")
    parser.add_argument('-o', '--output', type=str, help="output file name")

    args = parser.parse_args()

    try:
        generate(**args.__dict__)
    except IOError as ex:
        print(ex)
        exit(1)


def generate(ports=8, name=None, output=None):
    if type(ports) is int:
        n = ports
    elif len(ports) == 1:
        n = ports[0]
    else:
        print("Missing or incorrect number of ports")
        exit(1)

    if name is None:
        name = "axil_simd_wrap_{0}".format(n)

    if output is None:
        output = name + ".v"

    print("Generating {0}-port AXI lite simd wrapper {1}...".format(n, name))

    cn = (n-1).bit_length()

    t = Template(u"""
// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 lite {{n}} simd (wrapper)
 */
module {{name}} #
(
    // Width of data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8)
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI lite slave interfaces
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
    input  wire [ADDR_WIDTH-1:0]    s_axil_araddr,
    input  wire [2:0]               s_axil_arprot,
    input  wire                     s_axil_arvalid,
    output wire                     s_axil_arready,
    output wire [DATA_WIDTH-1:0]    s_axil_rdata,
    output wire [1:0]               s_axil_rresp,
    output wire                     s_axil_rvalid,
    input  wire                     s_axil_rready,
    /*
     * AXI lite master interfaces
     */
{%- for p in range(n) %}
    output wire [ADDR_WIDTH-1:0]    m{{'%02d'%p}}_axil_awaddr,
    output wire [2:0]               m{{'%02d'%p}}_axil_awprot,
    output wire                     m{{'%02d'%p}}_axil_awvalid,
    input  wire                     m{{'%02d'%p}}_axil_awready,
    output wire [DATA_WIDTH-1:0]    m{{'%02d'%p}}_axil_wdata,
    output wire [STRB_WIDTH-1:0]    m{{'%02d'%p}}_axil_wstrb,
    output wire                     m{{'%02d'%p}}_axil_wvalid,
    input  wire                     m{{'%02d'%p}}_axil_wready,
    input  wire [1:0]               m{{'%02d'%p}}_axil_bresp,
    input  wire                     m{{'%02d'%p}}_axil_bvalid,
    output wire                     m{{'%02d'%p}}_axil_bready,
    output wire [ADDR_WIDTH-1:0]    m{{'%02d'%p}}_axil_araddr,
    output wire [2:0]               m{{'%02d'%p}}_axil_arprot,
    output wire                     m{{'%02d'%p}}_axil_arvalid,
    input  wire                     m{{'%02d'%p}}_axil_arready,
    input  wire [DATA_WIDTH-1:0]    m{{'%02d'%p}}_axil_rdata,
    input  wire [1:0]               m{{'%02d'%p}}_axil_rresp,
    input  wire                     m{{'%02d'%p}}_axil_rvalid,
    output wire                     m{{'%02d'%p}}_axil_rready{% if not loop.last %},{% endif %}
{% endfor -%}
);

localparam M_COUNT = {{n}};

axil_simd #(
    .M_COUNT(M_COUNT),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .STRB_WIDTH(STRB_WIDTH)
)
axil_simd_inst (
    .clk(clk),
    .rst(rst),
    .s_axil_awaddr(s_axil_awaddr),
    .s_axil_awprot(s_axil_awprot),
    .s_axil_awvalid(s_axil_awvalid),
    .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata),
    .s_axil_wstrb(s_axil_wstrb),
    .s_axil_wvalid(s_axil_wvalid),
    .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp),
    .s_axil_bvalid(s_axil_bvalid),
    .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr),
    .s_axil_arprot(s_axil_arprot),
    .s_axil_arvalid(s_axil_arvalid),
    .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata),
    .s_axil_rresp(s_axil_rresp),
    .s_axil_rvalid(s_axil_rvalid),
    .s_axil_rready(s_axil_rready),
    .m_axil_awaddr({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awaddr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awprot({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awprot{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_awready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_awready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wdata({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wdata{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wstrb({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wstrb{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_wready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_wready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_bresp({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_bresp{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_bvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_bvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_bready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_bready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_araddr({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_araddr{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_arprot({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_arprot{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_arvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_arvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_arready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_arready{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rdata({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rdata{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rresp({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rresp{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rvalid({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rvalid{% if not loop.last %}, {% endif %}{% endfor %} }),
    .m_axil_rready({ {% for p in range(n-1,-1,-1) %}m{{'%02d'%p}}_axil_rready{% if not loop.last %}, {% endif %}{% endfor %} })
);

endmodule

`resetall

""")

    print(f"Writing file '{output}'...")

    with open(output, 'w') as f:
        f.write(t.render(
            n=n,
            cn=cn,
            name=name
        ))
        f.flush()

    print("Done")


if __name__ == "__main__":
    main()
