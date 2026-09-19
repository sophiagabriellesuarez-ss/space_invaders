![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Space Invaders Game

A hardware-level Space Invaders-style arcade game written in Verilog for the Tiny Tapeout platform. The game generates a 640x480 @ 60Hz VGA signal entirely in hardware, featuring custom pixel-art sprites, procedural backgrounds, and rapid-fire collision mechanics.

## Features

- Procedural VGA Rendering: No framebuffer or external video memory is used. Graphics are generated on-the-fly (beam racing) as the VGA coordinate counters sweep across the screen.

- Custom Sprites: Player rockets and alien crabs are defined as binary arrays directly in the Verilog code and rendered dynamically at a 4x scale.

- Procedural Starfield: The background features a sparse, dim-blue starfield generated using a bitwise pseudo-random formula on the current pixel coordinates.

- Rapid-Fire Combat: Players can track and fire up to three active bullets on the screen simultaneously.

- Hardware Gamepad Support: Interfaces directly with a SNES-style Gamepad PMOD via a custom serial latch/clock/data decoder.

## How it Works

- Game Logic Loop: The core game state updates exactly once per frame, triggered by the falling edge of the VGA vsync signal. The player controls a rocket ship at the bottom of the screen while an array of aliens moves horizontally, bouncing off the screen edges and dropping lower upon each bounce.

- Collision Detection: Bounding box logic continuously checks if any active bullets intersect with the coordinates of "alive" aliens. If a hit is detected during the frame tick, the bullet despawns and the specific alien's alive-state flag is cleared.

- Sprite Rendering Engine: The logic maps the current screen pixel coordinates (pix_x, pix_y) to the bounding box of the active entity. It divides the coordinate offset by 4 (to achieve 4x scaling) and samples the corresponding bit from the sprite array to determine if a colored pixel should be driven to the VGA pins.

## External Hardware Requirements

- To play the game on physical hardware, you will need the following peripherals:

- Tiny Tapeout Demo Board: The base carrier board providing the 25MHz clock, power, and IO headers.

- VGA PMOD: Connects to the dedicated output pins (uo_out) to drive the monitor display.

- Gamepad PMOD: A controller interface (designed by Psychogenic Technologies) connecting to the dedicated input pins (ui_in). It relies on a serial interface: LATCH on ui_in[4], CLOCK on ui_in[5], and DATA on ui_in[6].

Note: If the gamepad is not present, the game automatically falls back to raw pin inputs. You can manually play by toggling the raw input pins (Pin 2 for Left, Pin 3 for Right, Pin 4 for Shoot).

