# Weekly Progress Report – Week 02  
**Date:** November 14, 2025

### Accomplished This Week
- Studied basic principles of combinational logic design and carry propagation in adders
- Designed and implemented a 1-bit "Half-Adder" module in Verilog:
  - Used structural description (XOR for sum, AND for carry)
  - Followed basic coding style guidelines for readability and synthesis
- Developed a complete testbench for the Half-Adder:
  - Exhaustive testing of all 4 input combinations (00, 01, 10, 11)
  - Added self-checking assertions for output verification
- Performed functional simulation using Cadence Xcelium:
  - Captured and analyzed waveform in SimVision
  - Verified correct behavior for both sum and carry outputs
- Added simulation artifacts to the repository:
  - RTL code → `rtl/half_adder.v`
  - Testbench → `simulation/tb_half_adder.v`
  - Waveform screenshot → `simulation/half_adder_waveform.png`

### Key Learnings / Insights
- Gained first practical experience with Verilog module definition, port declaration, and continuous assignments
- Understood the importance of complete test coverage even for very simple designs
- Became familiar with the Xcelium → SimVision workflow for waveform debugging

### Challenges & Blocking Points
- Initial git commit failed due to unset user.name and user.email (resolved by global configuration)
- Minor confusion with PowerShell file copy syntax due to filename spaces (resolved by renaming files with underscores)

### Plan for Next Week
- Design and implement a 1-bit "Full Adder" (including carry-in) in Verilog
- Create corresponding testbench and perform exhaustive simulation