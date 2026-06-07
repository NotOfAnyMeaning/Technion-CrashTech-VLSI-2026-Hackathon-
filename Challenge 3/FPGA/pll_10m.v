// ============================================================
// pll_10m.v — ALTPLL wrapper: 50 MHz → 10 MHz
// CrashTech VLSI-2026 — Challenge 5: FPGA Volt-Meter
// ============================================================
// The MAX 10 internal ADC requires a dedicated 10 MHz clock
// supplied to its ADC block via the ALTPLL megafunction.
// This module is self-contained — no MegaWizard generation
// required. Quartus resolves ALTPLL from the Altera library.
//
// Input : inclk0  — 50 MHz system clock (MAX10_CLK1_50)
// Output: clk10m  — 10 MHz ADC clock   (divide by 5)
//         locked  — asserted when PLL is locked
// ============================================================

module pll_10m (
    input  inclk0,
    output clk10m,
    output locked
);

    wire [4:0] clk_bus;
    assign clk10m = clk_bus[0];

    altpll #(
        .bandwidth_type           ("AUTO"),
        .clk0_divide_by           (5),
        .clk0_duty_cycle          (50),
        .clk0_multiply_by         (1),
        .clk0_phase_shift         ("0"),
        .inclk0_input_frequency   (20000),       // 50 MHz → period = 20000 ps
        .intended_device_family   ("MAX 10"),
        .lpm_type                 ("altpll"),
        .operation_mode           ("NORMAL"),
        .pll_type                 ("AUTO"),
        .port_activeclock         ("PORT_UNUSED"),
        .port_areset              ("PORT_UNUSED"),
        .port_clkbad0             ("PORT_UNUSED"),
        .port_clkbad1             ("PORT_UNUSED"),
        .port_clkloss             ("PORT_UNUSED"),
        .port_clkswitch           ("PORT_UNUSED"),
        .port_configupdate        ("PORT_UNUSED"),
        .port_fbin                ("PORT_UNUSED"),
        .port_inclk0              ("PORT_USED"),
        .port_inclk1              ("PORT_UNUSED"),
        .port_locked              ("PORT_USED"),
        .port_pfdena              ("PORT_UNUSED"),
        .port_phasecounterselect  ("PORT_UNUSED"),
        .port_phasedone           ("PORT_UNUSED"),
        .port_phasestep           ("PORT_UNUSED"),
        .port_phaseupdown         ("PORT_UNUSED"),
        .port_pllena              ("PORT_UNUSED"),
        .port_scanaclr            ("PORT_UNUSED"),
        .port_scanclk             ("PORT_UNUSED"),
        .port_scanclkena          ("PORT_UNUSED"),
        .port_scandata            ("PORT_UNUSED"),
        .port_scandataout         ("PORT_UNUSED"),
        .port_scandone            ("PORT_UNUSED"),
        .port_scanread            ("PORT_UNUSED"),
        .port_scanwrite           ("PORT_UNUSED"),
        .port_clk0                ("PORT_USED"),
        .port_clk1                ("PORT_UNUSED"),
        .port_clk2                ("PORT_UNUSED"),
        .port_clk3                ("PORT_UNUSED"),
        .port_clk4                ("PORT_UNUSED"),
        .self_reset_on_loss_of_lock("OFF"),
        .width_clock              (5)
    ) altpll_comp (
        .inclk          ({1'b0, inclk0}),
        .clk            (clk_bus),
        .locked         (locked),
        // ---- unused ports tied off ----
        .activeclock    (),
        .areset         (1'b0),
        .clkbad         (),
        .clkena         ({6{1'b1}}),
        .clkloss        (),
        .clkswitch      (1'b0),
        .configupdate   (1'b0),
        .enable0        (),
        .enable1        (),
        .extclk         (),
        .extclkena      ({4{1'b1}}),
        .fbin           (1'b1),
        .fbmimicbidir   (),
        .fbout          (),
        .fref           (),
        .icdrclk        (),
        .pfdena         (1'b1),
        .phasecounterselect ({4{1'b1}}),
        .phasedone      (),
        .phasestep      (1'b1),
        .phaseupdown    (1'b1),
        .pllena         (1'b1),
        .scanaclr       (1'b0),
        .scanclk        (1'b0),
        .scanclkena     (1'b1),
        .scandata       (1'b0),
        .scandataout    (),
        .scandone       (),
        .scanread       (1'b0),
        .scanwrite      (1'b0),
        .sclkout0       (),
        .sclkout1       (),
        .vcooverrange   (),
        .vcounderrange  ()
    );

endmodule
