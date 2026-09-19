`default_nettype none
module tt_um_space_invaders (
    input  wire [7:0] ui_in,    // Dedicated inputs (gamepad)
    output wire [7:0] uo_out,   // Dedicated outputs (VGA PMOD)
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Power enable (ignored)
    input  wire       clk,      // 25MHz clock
    input  wire       rst_n     // reset_n - low to reset
);
    // Disable bidirectional IOs
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // VGA signals
    wire hsync;
    wire vsync;
    wire [1:0] R;
    wire [1:0] G;
    wire [1:0] B;
    wire video_active;
    wire [9:0] pix_x;
    wire [9:0] pix_y;

    // Tiny Tapeout VGA PMOD mapping
    assign uo_out[0] = R[1];
    assign uo_out[1] = G[1];
    assign uo_out[2] = B[1];
    assign uo_out[3] = vsync;
    assign uo_out[4] = R[0];
    assign uo_out[5] = G[0];
    assign uo_out[6] = B[0];
    assign uo_out[7] = hsync;

    // VGA Sync Generator (640x480 @ 60Hz)
    vga_sync vga (
        .clk(clk),
        .rst_n(rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .video_active(video_active),
        .pix_x(pix_x),
        .pix_y(pix_y)
    );

    // Game Inputs
    wire gp_left, gp_right, gp_a, gp_b;
    wire gp_is_present;
    
    gamepad_pmod_single gamepad (
        .rst_n(rst_n),
        .clk(clk),
        .pmod_data(ui_in[6]),
        .pmod_clk(ui_in[5]),
        .pmod_latch(ui_in[4]),
        .b(gp_b),
        .y(),
        .select(),
        .start(),
        .up(),
        .down(),
        .left(gp_left),
        .right(gp_right),
        .a(gp_a),
        .x(),
        .l(),
        .r(),
        .is_present(gp_is_present)
    );

    wire btn_left  = gp_is_present ? gp_left        : ui_in[2];
    wire btn_right = gp_is_present ? gp_right       : ui_in[3];
    wire btn_shoot = gp_is_present ? (gp_a | gp_b)  : ui_in[4];

    // Game State Registers
    reg [9:0] player_x;
    reg [9:0] alien_x;
    reg [9:0] alien_y;
    reg       alien_dir;
    reg [3:0] aliens_alive;

    // Rapid Fire: 3 active bullets
    reg [9:0] b0_x, b1_x, b2_x;
    reg [9:0] b0_y, b1_y, b2_y;
    reg       b0_act, b1_act, b2_act;
    reg       btn_shoot_prev;

    reg vsync_prev;
    always @(posedge clk) vsync_prev <= vsync;
    wire frame_tick = (vsync_prev && !vsync);

    // Bounding Box Layouts (4x scaling)
    localparam PLAYER_Y = 430;
    wire [9:0] a0_left = alien_x;
    wire [9:0] a1_left = alien_x + 40;
    wire [9:0] a2_left = alien_x + 80;
    wire [9:0] a3_left = alien_x + 120;

    // Main Game Logic Loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x      <= 320;
            alien_x       <= 100;
            alien_y       <= 50;
            alien_dir     <= 1;
            aliens_alive  <= 4'b1111;
            
            b0_act <= 0; b1_act <= 0; b2_act <= 0;
            b0_y <= 0; b1_y <= 0; b2_y <= 0;
            b0_x <= 0; b1_x <= 0; b2_x <= 0;
            btn_shoot_prev <= 0;
        end else if (frame_tick) begin
            btn_shoot_prev <= btn_shoot;

            // 1. Player movement
            if (btn_left && player_x > 20) player_x <= player_x - 4;
            if (btn_right && player_x < 600) player_x <= player_x + 4;

            // 2. Bullet logic (Spawn on rising edge of shoot button)
            if (btn_shoot && !btn_shoot_prev) begin
                if (!b0_act) begin
                    b0_act <= 1; b0_x <= player_x; b0_y <= PLAYER_Y;
                end else if (!b1_act) begin
                    b1_act <= 1; b1_x <= player_x; b1_y <= PLAYER_Y;
                end else if (!b2_act) begin
                    b2_act <= 1; b2_x <= player_x; b2_y <= PLAYER_Y;
                end
            end

            // Move active bullets
            if (b0_act) begin if (b0_y > 10) b0_y <= b0_y - 8; else b0_act <= 0; end
            if (b1_act) begin if (b1_y > 10) b1_y <= b1_y - 8; else b1_act <= 0; end
            if (b2_act) begin if (b2_y > 10) b2_y <= b2_y - 8; else b2_act <= 0; end

            // 3. Alien movement
            if (alien_dir == 1) begin
                if (alien_x < 480) alien_x <= alien_x + 2;
                else begin
                    alien_dir <= 0;
                    alien_y   <= alien_y + 32;
                end
            end else begin
                if (alien_x > 20) alien_x <= alien_x - 2;
                else begin
                    alien_dir <= 1;
                    alien_y   <= alien_y + 32;
                end
            end

            // 4. Collision detection (Check each active bullet against all alive aliens)
            if (b0_act) begin
                if (aliens_alive[0] && b0_y >= alien_y && b0_y <= alien_y + 32 && b0_x >= a0_left && b0_x <= a0_left + 32) begin aliens_alive[0] <= 0; b0_act <= 0; end
                if (aliens_alive[1] && b0_y >= alien_y && b0_y <= alien_y + 32 && b0_x >= a1_left && b0_x <= a1_left + 32) begin aliens_alive[1] <= 0; b0_act <= 0; end
                if (aliens_alive[2] && b0_y >= alien_y && b0_y <= alien_y + 32 && b0_x >= a2_left && b0_x <= a2_left + 32) begin aliens_alive[2] <= 0; b0_act <= 0; end
                if (aliens_alive[3] && b0_y >= alien_y && b0_y <= alien_y + 32 && b0_x >= a3_left && b0_x <= a3_left + 32) begin aliens_alive[3] <= 0; b0_act <= 0; end
            end
            if (b1_act) begin
                if (aliens_alive[0] && b1_y >= alien_y && b1_y <= alien_y + 32 && b1_x >= a0_left && b1_x <= a0_left + 32) begin aliens_alive[0] <= 0; b1_act <= 0; end
                if (aliens_alive[1] && b1_y >= alien_y && b1_y <= alien_y + 32 && b1_x >= a1_left && b1_x <= a1_left + 32) begin aliens_alive[1] <= 0; b1_act <= 0; end
                if (aliens_alive[2] && b1_y >= alien_y && b1_y <= alien_y + 32 && b1_x >= a2_left && b1_x <= a2_left + 32) begin aliens_alive[2] <= 0; b1_act <= 0; end
                if (aliens_alive[3] && b1_y >= alien_y && b1_y <= alien_y + 32 && b1_x >= a3_left && b1_x <= a3_left + 32) begin aliens_alive[3] <= 0; b1_act <= 0; end
            end
            if (b2_act) begin
                if (aliens_alive[0] && b2_y >= alien_y && b2_y <= alien_y + 32 && b2_x >= a0_left && b2_x <= a0_left + 32) begin aliens_alive[0] <= 0; b2_act <= 0; end
                if (aliens_alive[1] && b2_y >= alien_y && b2_y <= alien_y + 32 && b2_x >= a1_left && b2_x <= a1_left + 32) begin aliens_alive[1] <= 0; b2_act <= 0; end
                if (aliens_alive[2] && b2_y >= alien_y && b2_y <= alien_y + 32 && b2_x >= a2_left && b2_x <= a2_left + 32) begin aliens_alive[2] <= 0; b2_act <= 0; end
                if (aliens_alive[3] && b2_y >= alien_y && b2_y <= alien_y + 32 && b2_x >= a3_left && b2_x <= a3_left + 32) begin aliens_alive[3] <= 0; b2_act <= 0; end
            end
        end
    end

    // Sprite Bitmaps (unchanged data, but drawn bigger below)
    function [7:0] rocket_row;
        input [2:0] row;
        begin
            case (row)
                3'd0: rocket_row = 8'b00011000;
                3'd1: rocket_row = 8'b00111100;
                3'd2: rocket_row = 8'b01111110;
                3'd3: rocket_row = 8'b01111110;
                3'd4: rocket_row = 8'b01100110;
                3'd5: rocket_row = 8'b11111111;
                3'd6: rocket_row = 8'b01011010;
                default: rocket_row = 8'b00000000;
            endcase
        end
    endfunction

    function [7:0] alien_row;
        input [2:0] row;
        begin
            case (row)
                3'd0: alien_row = 8'b00100100;
                3'd1: alien_row = 8'b00111100;
                3'd2: alien_row = 8'b01111110;
                3'd3: alien_row = 8'b11011011;
                3'd4: alien_row = 8'b11111111;
                3'd5: alien_row = 8'b10111101;
                3'd6: alien_row = 8'b01000010;
                3'd7: alien_row = 8'b10000001;
                default: alien_row = 8'b00000000;
            endcase
        end
    endfunction

    // --- Player rocket (Drawn at 4x scale -> 32x28 on screen) ---
    wire [9:0] player_left = player_x - 16;
    wire       in_player_box = (pix_x >= player_left) && (pix_x < player_left + 32) &&
                               (pix_y >= PLAYER_Y)    && (pix_y < PLAYER_Y + 28);
                               
    wire [9:0] player_dx = pix_x - player_left;
    wire [9:0] player_dy = pix_y - PLAYER_Y;
    wire [2:0] player_col = player_dx[4:2]; // Divide by 4
    wire [2:0] player_row = player_dy[4:2]; // Divide by 4
    
    wire [7:0] player_bits = rocket_row(player_row);
    wire draw_player = in_player_box && player_bits[7 - player_col];

    // --- Aliens (Drawn at 4x scale -> 32x32 on screen) ---
    wire in_a0_box = aliens_alive[0] && (pix_x >= a0_left) && (pix_x < a0_left + 32) && (pix_y >= alien_y) && (pix_y < alien_y + 32);
    wire in_a1_box = aliens_alive[1] && (pix_x >= a1_left) && (pix_x < a1_left + 32) && (pix_y >= alien_y) && (pix_y < alien_y + 32);
    wire in_a2_box = aliens_alive[2] && (pix_x >= a2_left) && (pix_x < a2_left + 32) && (pix_y >= alien_y) && (pix_y < alien_y + 32);
    wire in_a3_box = aliens_alive[3] && (pix_x >= a3_left) && (pix_x < a3_left + 32) && (pix_y >= alien_y) && (pix_y < alien_y + 32);

    wire [9:0] a0_dx = pix_x - a0_left; wire [9:0] a0_dy = pix_y - alien_y;
    wire [9:0] a1_dx = pix_x - a1_left; wire [9:0] a1_dy = pix_y - alien_y;
    wire [9:0] a2_dx = pix_x - a2_left; wire [9:0] a2_dy = pix_y - alien_y;
    wire [9:0] a3_dx = pix_x - a3_left; wire [9:0] a3_dy = pix_y - alien_y;

    wire [2:0] a0_col = a0_dx[4:2]; wire [2:0] a0_row = a0_dy[4:2];
    wire [2:0] a1_col = a1_dx[4:2]; wire [2:0] a1_row = a1_dy[4:2];
    wire [2:0] a2_col = a2_dx[4:2]; wire [2:0] a2_row = a2_dy[4:2];
    wire [2:0] a3_col = a3_dx[4:2]; wire [2:0] a3_row = a3_dy[4:2];

    wire [7:0] a0_bits = alien_row(a0_row);
    wire [7:0] a1_bits = alien_row(a1_row);
    wire [7:0] a2_bits = alien_row(a2_row);
    wire [7:0] a3_bits = alien_row(a3_row);

    wire draw_a0 = in_a0_box && a0_bits[7 - a0_col];
    wire draw_a1 = in_a1_box && a1_bits[7 - a1_col];
    wire draw_a2 = in_a2_box && a2_bits[7 - a2_col];
    wire draw_a3 = in_a3_box && a3_bits[7 - a3_col];
    wire draw_alien = draw_a0 | draw_a1 | draw_a2 | draw_a3;

    // --- Multiple Bullets ---
    wire draw_b0 = b0_act && (pix_x >= b0_x - 1 && pix_x <= b0_x + 1 && pix_y >= b0_y && pix_y <= b0_y + 8);
    wire draw_b1 = b1_act && (pix_x >= b1_x - 1 && pix_x <= b1_x + 1 && pix_y >= b1_y && pix_y <= b1_y + 8);
    wire draw_b2 = b2_act && (pix_x >= b2_x - 1 && pix_x <= b2_x + 1 && pix_y >= b2_y && pix_y <= b2_y + 8);
    wire draw_bullet = draw_b0 | draw_b1 | draw_b2;

    // --- Starfield Background ---
    // A bitwise pseudo-random formula that generates a sparse speckled field
    wire is_star = ((pix_x[5:3] ^ pix_y[6:4]) == 3'b101) && (pix_x[1:0] == 2'b11) && (pix_y[1:0] == 2'b11);

    // Color assignments
    wire [1:0] out_r = draw_alien  ? 2'b11 : (draw_bullet ? 2'b11 : (is_star ? 2'b01 : 2'b00));
    wire [1:0] out_g = draw_player ? 2'b11 : (draw_bullet ? 2'b11 : (is_star ? 2'b01 : 2'b00));
    wire [1:0] out_b = draw_bullet ? 2'b11 : (is_star ? 2'b10 : 2'b00); // Stars are slightly bluish

    assign R = video_active ? out_r : 2'b00;
    assign G = video_active ? out_g : 2'b00;
    assign B = video_active ? out_b : 2'b00;
endmodule