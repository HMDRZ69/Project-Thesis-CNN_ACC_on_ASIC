// This is the weekly report of my Project Thesis: 
// Design a basic CNN Accelerator on an ASIC in IHP 130nm Technology
cnn-asic/                     # top-level git repo
  README.md
  doc/                        # docs, PDK notes, meeting notes
  rtl/                        # Verilog / SV sources
    core/                     # convolution engine RTL
    mem/                      # SRAM wrapper / controller
    tb/                       # testbenches
    dsp/                      # MAC, multiplier units
  sim/                        # simulation scripts and waves
  synthesis/                  # synthesis scripts (Genus)
  floorplan/                  # floorplan constraints, power rings
  pnr/                        # Innovus scripts
  signoff/                    # extraction & signoff scripts
  pdk/                        # small wrapper files/techfiles (NOT full PDK)
  gds/                        # output GDSII (do not commit full PDK)
