<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is a hardware-level Space Invaders-style arcade game written in Verilog for the Tiny Tapeout platform.

Game Logic: The game state updates once per frame, triggered by the VGA vsync signal's falling edge. The player controls a rocket ship at the bottom of the screen and can fire up to three bullets simultaneously (rapid fire) at a descending wave of alien crabs. Aliens move horizontally, bouncing off the screen edges and dropping lower upon each bounce.

Collision Detection: Bounding box logic checks if active bullets intersect with any "alive" aliens. If a hit is detected, the bullet despawns and the specific alien's alive-state flag is cleared.

Rendering (Beam Racing): Because Tiny Tapeout designs typically lack the memory for a full framebuffer, graphics are generated procedurally on-the-fly at 640x480 @ 60Hz.

Sprites: The rocket ship and alien characters are defined as small binary arrays (8x7 and 8x8) and rendered at a 4x scale. The logic maps the current screen pixel coordinates (pix_x, pix_y) to the bounding box of the entity and samples the specific bit to determine if a color should be drawn.

Background: The outer space starfield is generated procedurally using a bitwise pseudo-random formula ((pix_x[5:3] ^ pix_y[6:4]) == 3'b101) combined with coordinate masking, painting dim blue pixels across the screen without requiring memory storage.

## How to test

Software Simulation
The project includes a Cocotb-based testbench that simulates the hardware and verifies the VGA output.

The testbench toggles the clock, resets the design, and captures the VGA output signals (uo_out) over several simulated frames.

It decodes the raw hsync, vsync, and RGB signals back into image frames using Python and Pillow.

The test compares these newly generated frames against known-good reference images (reference/frameX.png). If the visual output diverges, the test fails and saves a diff image.

To run the simulation locally, install the dependencies (pip install -r test/requirements.txt) and execute the test suite using pytest.

## Hardware Testing

Once fabricated or loaded onto an FPGA emulation board (like the Tiny Tapeout Demo Board):

Connect the VGA PMOD and plug it into a 640x480 60Hz compatible monitor.

Connect the Gamepad PMOD.

Power the board, select the project via the DIP switches or commander app, and use the gamepad's D-Pad to move left/right and the A/B buttons to shoot.

If a gamepad is not present, you can manually test by toggling the raw input pins (Pin 2 for Left, Pin 3 for Right, Pin 4 for Shoot).

## External hardware

To play the game on physical hardware, you need the following peripherals:

Tiny Tapeout Demo Board: The base carrier board providing clock, power, and IO headers.

VGA PMOD: Required to display the video output. It connects to the dedicated output pins (uo_out).

Gamepad PMOD: A SNES-style controller interface (specifically the one by Psychogenic Technologies) to control the game. It connects to the dedicated input pins (ui_in), relying on a serial latch/clock/data interface (LATCH on ui_in[4], CLOCK on ui_in[5], and DATA on ui_in[6]).
