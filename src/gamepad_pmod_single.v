/*
 * Copyright (c) 2025 Pat Deegan
 * https://psychogenic.com
 * SPDX-License-Identifier: Apache-2.0
 *
 * Interfacing code for the Gamepad Pmod from Psychogenic Technologies,
 * designed for Tiny Tapeout.
 *
 * There are two high-level modules that most users will be interested in:
 *  - gamepad_pmod_single: for a single controller;
 *  - gamepad_pmod_dual: for two controllers.
 *
 * There are also two lower-level modules that you can use if you want to
 * handle the interfacing yourself:
 *  - gamepad_pmod_driver: interfaces with the Pmod and provides the raw data;
 *  - gamepad_pmod_decoder: decodes the raw data into button states.
 *
 * The docs, schematics, PCB files, and firmware code for the Gamepad Pmod
 * are available at https://github.com/psychogenic/gamepad-pmod.
 */

`default_nettype none

/**
 * gamepad_pmod_driver -- Serial interface for the Gamepad Pmod.
 *
 * This module reads raw data from the Gamepad Pmod *serially*
 * and stores it in a shift register. When the latch signal is received,
 * the data is transferred into `data_reg` for further processing.
 */
module gamepad_pmod_driver #(
    parameter BIT_WIDTH = 24
) (
    input  wire                    rst_n,
    input  wire                    clk,
    input  wire                    pmod_data,
    input  wire                    pmod_clk,
    input  wire                    pmod_latch,
    output reg  [BIT_WIDTH-1:0]    data_reg
);

    reg pmod_clk_prev;
    reg pmod_latch_prev;
    reg [BIT_WIDTH-1:0] shift_reg;

    // Sync Pmod signals to the clk domain:
    reg [1:0] pmod_data_sync;
    reg [1:0] pmod_clk_sync;
    reg [1:0] pmod_latch_sync;

    always @(posedge clk) begin
        if (~rst_n) begin
            pmod_data_sync  <= 2'b0;
            pmod_clk_sync   <= 2'b0;
            pmod_latch_sync <= 2'b0;
        end else begin
            pmod_data_sync  <= {pmod_data_sync[0], pmod_data};
            pmod_clk_sync   <= {pmod_clk_sync[0], pmod_clk};
            pmod_latch_sync <= {pmod_latch_sync[0], pmod_latch};
        end
    end

    always @(posedge clk) begin
        if (~rst_n) begin
            /* set data and shift registers to all ones
             * such that it is detected as "not present" yet.
             */
            data_reg        <= {BIT_WIDTH{1'b1}};
            shift_reg       <= {BIT_WIDTH{1'b1}};
            pmod_clk_prev   <= 1'b0;
            pmod_latch_prev <= 1'b0;
        end else begin
            pmod_clk_prev   <= pmod_clk_sync[1];
            pmod_latch_prev <= pmod_latch_sync[1];

            // Capture data on rising edge of pmod_latch:
            if (pmod_latch_sync[1] & ~pmod_latch_prev) begin
                data_reg <= shift_reg;
            end

            // Sample data on rising edge of pmod_clk:
            if (pmod_clk_sync[1] & ~pmod_clk_prev) begin
                shift_reg <= {shift_reg[BIT_WIDTH-2:0], pmod_data_sync[1]};
            end
        end
    end

endmodule

/**
 * gamepad_pmod_decoder -- Decodes raw data from the Gamepad Pmod.
 *
 * Takes a 12-bit parallel data register (`data_reg`) and decodes it
 * into individual button states, plus a controller-present flag.
 */
module gamepad_pmod_decoder (
    input  wire [11:0] data_reg,
    output wire b,
    output wire y,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right,
    output wire a,
    output wire x,
    output wire l,
    output wire r,
    output wire is_present
);

    // When the controller is not connected, the data register will be all 1's
    wire reg_empty = (data_reg == 12'hfff);

    assign is_present = reg_empty ? 0 : 1'b1;
    assign {b, y, select, start, up, down, left, right, a, x, l, r} = reg_empty ? 12'b0 : data_reg;

endmodule

/**
 * gamepad_pmod_single -- Main interface for a single Gamepad Pmod controller.
 *
 * Default Tiny Tapeout wiring:
 *   pmod_latch -> ui_in[4]
 *   pmod_clk   -> ui_in[5]
 *   pmod_data  -> ui_in[6]
 */
module gamepad_pmod_single (
    input  wire rst_n,
    input  wire clk,
    input  wire pmod_data,
    input  wire pmod_clk,
    input  wire pmod_latch,
    output wire b,
    output wire y,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right,
    output wire a,
    output wire x,
    output wire l,
    output wire r,
    output wire is_present
);

    wire [11:0] gamepad_pmod_data;

    gamepad_pmod_driver #(
        .BIT_WIDTH(12)
    ) driver (
        .rst_n(rst_n),
        .clk(clk),
        .pmod_data(pmod_data),
        .pmod_clk(pmod_clk),
        .pmod_latch(pmod_latch),
        .data_reg(gamepad_pmod_data)
    );

    gamepad_pmod_decoder decoder (
        .data_reg(gamepad_pmod_data),
        .b(b),
        .y(y),
        .select(select),
        .start(start),
        .up(up),
        .down(down),
        .left(left),
        .right(right),
        .a(a),
        .x(x),
        .l(l),
        .r(r),
        .is_present(is_present)
    );

endmodule

/**
 * gamepad_pmod_dual -- Main interface for two Gamepad Pmod controllers.
 * Each button is a 2-bit vector: index 0 = controller 1, index 1 = controller 2.
 */
module gamepad_pmod_dual (
    input  wire rst_n,
    input  wire clk,
    input  wire pmod_data,
    input  wire pmod_clk,
    input  wire pmod_latch,
    output wire [1:0] b,
    output wire [1:0] y,
    output wire [1:0] select,
    output wire [1:0] start,
    output wire [1:0] up,
    output wire [1:0] down,
    output wire [1:0] left,
    output wire [1:0] right,
    output wire [1:0] a,
    output wire [1:0] x,
    output wire [1:0] l,
    output wire [1:0] r,
    output wire [1:0] is_present
);

    wire [23:0] gamepad_pmod_data;

    gamepad_pmod_driver driver (
        .rst_n(rst_n),
        .clk(clk),
        .pmod_data(pmod_data),
        .pmod_clk(pmod_clk),
        .pmod_latch(pmod_latch),
        .data_reg(gamepad_pmod_data)
    );

    gamepad_pmod_decoder decoder1 (
        .data_reg(gamepad_pmod_data[11:0]),
        .b(b[0]), .y(y[0]), .select(select[0]), .start(start[0]),
        .up(up[0]), .down(down[0]), .left(left[0]), .right(right[0]),
        .a(a[0]), .x(x[0]), .l(l[0]), .r(r[0]),
        .is_present(is_present[0])
    );

    gamepad_pmod_decoder decoder2 (
        .data_reg(gamepad_pmod_data[23:12]),
        .b(b[1]), .y(y[1]), .select(select[1]), .start(start[1]),
        .up(up[1]), .down(down[1]), .left(left[1]), .right(right[1]),
        .a(a[1]), .x(x[1]), .l(l[1]), .r(r[1]),
        .is_present(is_present[1])
    );

endmodule
