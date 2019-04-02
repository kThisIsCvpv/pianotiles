# Piano Tiles [DE2 Board Remake]
##### Winter 2019 - CSCB58 Final Project - Charles Xu and Eugene Wong
# 
#
This project is our submission for Winter 2019's CSCB58 final project led by instructor Moshe Gabel.
This project is a remake of the popular mobile game Piano Tiles.

# Requirements: 
- Cyclone IV FPGA DE2 board
- VGA source monitor

# Game Description:
- Tiles will fall from the top of the screen to the bottom in length 50px.
- Tiles will fall in columns of 4.
- Each column will correspond to KEY switches on the DE2 board.
- Press the KEY [3:0] switch for the corresponding column before the tile fully disappears to clear it.
- Player score is kept track on HEX[1:0] in hexidecimal. 1 point is earned for each cleared tile.
- The game is over when a tile is not cleared before it fully disappears.

# Source:
- __Quartus Project File:__ pianotiles.qpf
- __Top Level Module:__ pianotiles.v
- __Output Loader File:__ output_files/pianotiles.sof