module fetal_ecg(
	input logic CLOCK_50,
	input logic CLOCK2_50,
	// 40-pin headers
	inout logic[35:0]	GPIO_0,
	inout logic[35:0]	GPIO_1,
	// DDR3 SDRAM
	output logic[14:0] HPS_DDR3_ADDR,
	output logic[2:0] HPS_DDR3_BA,
	output logic HPS_DDR3_CAS_N,
	output logic HPS_DDR3_CKE,
	output logic HPS_DDR3_CK_N,
	output logic HPS_DDR3_CK_P,
	output logic HPS_DDR3_CS_N,
	output logic[3:0]	HPS_DDR3_DM,
	inout logic[31:0] HPS_DDR3_DQ,
	inout logic[3:0] HPS_DDR3_DQS_N,
	inout logic[3:0] HPS_DDR3_DQS_P,
	output logic HPS_DDR3_ODT,
	output logic HPS_DDR3_RAS_N,
	output logic HPS_DDR3_RESET_N,
	input logic HPS_DDR3_RZQ,
	output logic HPS_DDR3_WE_N,
	// Ethernet
	output logic HPS_ENET_GTX_CLK,
	inout logic HPS_ENET_INT_N,
	output logic HPS_ENET_MDC,
	inout logic HPS_ENET_MDIO,
	input logic HPS_ENET_RX_CLK,
	input logic[3:0] HPS_ENET_RX_DATA,
	input logic HPS_ENET_RX_DV,
	output logic[3:0] HPS_ENET_TX_DATA,
	output logic HPS_ENET_TX_EN
);

	logic reset;
	logic[31:0] read_data, write_data;
	logic[13:0] address;
	logic[3:0] byte_enable;
	logic clk_en, chip_select, read, write, valid;
	
	initial sizes = '{16'd8, 16'd8, 16'd8};

//==================================================
// Matrix multiplication hardware accelerator
//==================================================
	
	matrix_multiplier(
		.clk(CLOCK_50),
		.reset(reset),
		.clk_en(clk_en),
		.read_data(read_data),
		.write_data(write_data),
		.address(address),
		.chip_select(chip_select),
		.byte_enable(byte_enable),
		.read(read),
		.write(write),
		.valid(valid)
	);
	
	
	
	module Computer_System (
		.hps_io_hps_io_emac1_inst_TX_CLK(HPS_ENET_GTX_CLK), // output .hps_io.hps_io_emac1_inst_TX_CLK
		.hps_io_hps_io_emac1_inst_TXD0(HPS_ENET_TX_DATA[0]),   // output .hps_io_emac1_inst_TXD0
		.hps_io_hps_io_emac1_inst_TXD1(HPS_ENET_TX_DATA[1]),   // output .hps_io_emac1_inst_TXD1
		.hps_io_hps_io_emac1_inst_TXD2(HPS_ENET_TX_DATA[2]),   // output .hps_io_emac1_inst_TXD2
		.hps_io_hps_io_emac1_inst_TXD3(HPS_ENET_TX_DATA[3]),   // output .hps_io_emac1_inst_TXD3
		.hps_io_hps_io_emac1_inst_RXD0(HPS_ENET_RX_DATA[0]),   // input .hps_io_emac1_inst_RXD0
		.hps_io_hps_io_emac1_inst_MDIO,   // inout .hps_io_emac1_inst_MDIO
		.hps_io_hps_io_emac1_inst_MDC,    // output .hps_io_emac1_inst_MDC
		.hps_io_hps_io_emac1_inst_RX_CTL, // input .hps_io_emac1_inst_RX_CTL
		.hps_io_hps_io_emac1_inst_TX_CTL, // output .hps_io_emac1_inst_TX_CTL
		.hps_io_hps_io_emac1_inst_RX_CLK, // input .hps_io_emac1_inst_RX_CLK
		.hps_io_hps_io_emac1_inst_RXD1,   // input .hps_io_emac1_inst_RXD1
		.hps_io_hps_io_emac1_inst_RXD2,   // input .hps_io_emac1_inst_RXD2
		.hps_io_hps_io_emac1_inst_RXD3,   // input .hps_io_emac1_inst_RXD3
		.hps_io_hps_io_qspi_inst_IO0,     // inout .hps_io_qspi_inst_IO0
		.hps_io_hps_io_qspi_inst_IO1,     // inout .hps_io_qspi_inst_IO1
		.hps_io_hps_io_qspi_inst_IO2,     // inout .hps_io_qspi_inst_IO2
		.hps_io_hps_io_qspi_inst_IO3,     // inout .hps_io_qspi_inst_IO3
		.hps_io_hps_io_qspi_inst_SS0,     // output .hps_io_qspi_inst_SS0
		.hps_io_hps_io_qspi_inst_CLK,     // output .hps_io_qspi_inst_CLK
		.hps_io_hps_io_sdio_inst_CMD,     // inout .hps_io_sdio_inst_CMD
		.hps_io_hps_io_sdio_inst_D0,      // inout .hps_io_sdio_inst_D0
		.hps_io_hps_io_sdio_inst_D1,      // inout .hps_io_sdio_inst_D1
		.hps_io_hps_io_sdio_inst_CLK,     // output .hps_io_sdio_inst_CLK
		.hps_io_hps_io_sdio_inst_D2,      // inout .hps_io_sdio_inst_D2
		.hps_io_hps_io_sdio_inst_D3,      // inout .hps_io_sdio_inst_D3
		.hps_io_hps_io_usb1_inst_D0,      // inout .hps_io_usb1_inst_D0
		.hps_io_hps_io_usb1_inst_D1,      // inout .hps_io_usb1_inst_D1
		.hps_io_hps_io_usb1_inst_D2,      // inout .hps_io_usb1_inst_D2
		.hps_io_hps_io_usb1_inst_D3,      // inout .hps_io_usb1_inst_D3
		.hps_io_hps_io_usb1_inst_D4,      // inout .hps_io_usb1_inst_D4
		.hps_io_hps_io_usb1_inst_D5,      // inout .hps_io_usb1_inst_D5
		.hps_io_hps_io_usb1_inst_D6,      // inout .hps_io_usb1_inst_D6
		.hps_io_hps_io_usb1_inst_D7,      // inout .hps_io_usb1_inst_D7
		.hps_io_hps_io_usb1_inst_CLK,     // input .hps_io_usb1_inst_CLK
		.hps_io_hps_io_usb1_inst_STP,     // output .hps_io_usb1_inst_STP
		.hps_io_hps_io_usb1_inst_DIR,     // input .hps_io_usb1_inst_DIR
		.hps_io_hps_io_usb1_inst_NXT,     // input .hps_io_usb1_inst_NXT
		.hps_io_hps_io_spim1_inst_CLK,    // output .hps_io_spim1_inst_CLK
		.hps_io_hps_io_spim1_inst_MOSI,   // output .hps_io_spim1_inst_MOSI
		.hps_io_hps_io_spim1_inst_MISO,   // input .hps_io_spim1_inst_MISO
		.hps_io_hps_io_spim1_inst_SS0,    // output .hps_io_spim1_inst_SS0
		.hps_io_hps_io_uart0_inst_RX,     // input .hps_io_uart0_inst_RX
		.hps_io_hps_io_uart0_inst_TX,     // output .hps_io_uart0_inst_TX
		.hps_io_hps_io_i2c0_inst_SDA,     // inout .hps_io_i2c0_inst_SDA
		.hps_io_hps_io_i2c0_inst_SCL,     // inout .hps_io_i2c0_inst_SCL
		.hps_io_hps_io_i2c1_inst_SDA,     // inout .hps_io_i2c1_inst_SDA
		.hps_io_hps_io_i2c1_inst_SCL,     // inout .hps_io_i2c1_inst_SCL
		.hps_io_hps_io_gpio_inst_GPIO09,  // inout .hps_io_gpio_inst_GPIO09
		.hps_io_hps_io_gpio_inst_GPIO35,  // inout .hps_io_gpio_inst_GPIO35
		.hps_io_hps_io_gpio_inst_GPIO40,  // inout .hps_io_gpio_inst_GPIO40
		.hps_io_hps_io_gpio_inst_GPIO41,  // inout .hps_io_gpio_inst_GPIO41
		.hps_io_hps_io_gpio_inst_GPIO48,  // inout .hps_io_gpio_inst_GPIO48
		.hps_io_hps_io_gpio_inst_GPIO53,  // inout .hps_io_gpio_inst_GPIO53
		.hps_io_hps_io_gpio_inst_GPIO54,  // inout .hps_io_gpio_inst_GPIO54
		.hps_io_hps_io_gpio_inst_GPIO61,  // inout .hps_io_gpio_inst_GPIO61
		.memory_mem_a,                    // output[14:0] memory.mem_a
		.memory_mem_ba,                   // output[2:0] .mem_ba
		.memory_mem_ck,                   // output .mem_ck
		.memory_mem_ck_n,                 // output .mem_ck_n
		.memory_mem_cke,                  // output .mem_cke
		.memory_mem_cs_n,                 // output .mem_cs_n
		.memory_mem_ras_n,                // output .mem_ras_n
		.memory_mem_cas_n,                // output .mem_cas_n
		.memory_mem_we_n,                 // output .mem_we_n
		.memory_mem_reset_n,              // output .mem_reset_n
		.memory_mem_dq,                   // inout[31:0] .mem_dq
		.memory_mem_dqs,                  // inout[3:0] .mem_dqs
		.memory_mem_dqs_n,                // inout[3:0] .mem_dqs_n
		.memory_mem_odt,                  // output .mem_odt
		.memory_mem_dm,                   // output[3:0] .mem_dm
		.memory_oct_rzqin,                // input .oct_rzqin
		.onchip_sram_clk2_clk(CLOCK2_50),            // input onchip_sram_clk2.clk
		.onchip_sram_reset2_reset(reset), // input onchip_sram_reset2.reset
		.onchip_sram_reset2_reset_req(), // input .reset_req
		.onchip_sram_s2_address(address), // input[13:0] onchip_sram_s2.address
		.onchip_sram_s2_chipselect(chip_select), // input .chipselect
		.onchip_sram_s2_clken(clk_en), // input .clken
		.onchip_sram_s2_write(write), // input .write
		.onchip_sram_s2_readdata(read_data), // output[31:0] .readdata
		.onchip_sram_s2_writedata(write_data), // input[31:0] .writedata
		.onchip_sram_s2_byteenable(byte_enable), // input[3:0] .byteenable
		.sdram_clk_clk(CLOCK_50), // output sdram_clk.clk
		.system_pll_ref_clk_clk(CLOCK_50),  // input system_pll_ref_clk.clk
		.system_pll_ref_reset_reset(reset) // input system_pll_ref_reset.reset
	);
	

endmodule
