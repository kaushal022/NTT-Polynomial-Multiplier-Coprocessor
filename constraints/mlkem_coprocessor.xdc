create_clock -period 10.000 -name s_axi_aclk -waveform {0.000 5.000} [get_ports s_axi_aclk]

set_clock_uncertainty 0.200 [get_clocks s_axi_aclk]

set_false_path -to [get_ports {s_axi_awready s_axi_wready s_axi_bresp* s_axi_bvalid s_axi_arready s_axi_rdata* s_axi_rresp* s_axi_rvalid irq}]
set_false_path -from [get_ports {s_axi_awaddr* s_axi_awvalid s_axi_wdata* s_axi_wstrb* s_axi_wvalid s_axi_bready s_axi_araddr* s_axi_arvalid s_axi_rready s_axi_aresetn}]
