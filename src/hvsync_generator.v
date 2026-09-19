// Helper Module: 640x480 VGA Sync Generator 
module vga_sync (
    input  wire clk,
    input  wire rst_n,
    output reg  hsync,
    output reg  vsync,
    output reg  video_active,
    output reg  [9:0] pix_x,
    output reg  [9:0] pix_y
);
    // VGA 640x480 @ 60Hz timing constants (25.175 MHz clock expected)
    parameter H_DISPLAY       = 640;
    parameter H_FRONT_PORCH   = 16;
    parameter H_SYNC_PULSE    = 96;
    parameter H_BACK_PORCH    = 48;
    parameter H_TOTAL         = 800;

    parameter V_DISPLAY       = 480;
    parameter V_FRONT_PORCH   = 10;
    parameter V_SYNC_PULSE    = 2;
    parameter V_BACK_PORCH    = 33;
    parameter V_TOTAL         = 525;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_x <= 0;
            pix_y <= 0;
            hsync <= 1; // Sync pulses active low
            vsync <= 1;
            video_active <= 0;
        end else begin
            if (pix_x == H_TOTAL - 1) begin
                pix_x <= 0;
                if (pix_y == V_TOTAL - 1) pix_y <= 0;
                else pix_y <= pix_y + 1;
            end else begin
                pix_x <= pix_x + 1;
            end

            hsync <= ~(pix_x >= (H_DISPLAY + H_FRONT_PORCH) && pix_x < (H_DISPLAY + H_FRONT_PORCH + H_SYNC_PULSE));
            vsync <= ~(pix_y >= (V_DISPLAY + V_FRONT_PORCH) && pix_y < (V_DISPLAY + V_FRONT_PORCH + V_SYNC_PULSE));

            video_active <= (pix_x < H_DISPLAY) && (pix_y < V_DISPLAY);
        end
    end
endmodule