# Basic CNN Accelerator on IHP 130nm Technology

**Project Thesis**  
**Student:** Hamed Ramezan Zadeh  
**Supervisor:** Prof. Dr. Florian Ashauer  
**Start Date:** November 2025

### Project Overview
Design and implementation of a lightweight hardware accelerator for Convolutional Neural Networks (CNNs) using IHP SG13S 130nm CMOS technology.  
The project follows a standard ASIC design flow: RTL design → verification → synthesis → place & route → sign-off.

### Repository Structure
- `weekly-reports/` → Weekly progress reports (one Markdown file per week)  
- `rtl/` → Verilog/SystemVerilog source codes (basic building blocks so far)  
- `simulation/` → Testbenches, simulation scripts, and waveform screenshots  
- `docs/` → Papers, datasheets, PDK notes, and references (to be expanded)  
- `layout/` → Cadence Virtuoso/Innovus flow files (setup in progress)

### Weekly Progress

| Week | Date         | Main Topic / Milestone                              | Report Link                                      |
|------|--------------|-----------------------------------------------------|--------------------------------------------------|
| 01   | 2025-11-07   | Initial study of ASIC flow & Cadence tool access    | [week-01.md](weekly-reports/week-01.md)          |
| 02   | 2025-11-14   | Verilog basics & Half-Adder implementation          | [week-02.md](weekly-reports/week-02.md)          |
| 03   | 2025-11-21   | AND gate, Half-Adder verification & server workflow | [week-03.md](weekly-reports/week-03.md)          |
| 04   | 2025-11-28   | Full-Adder design, simulation & IHP rules review    | [week-04.md](weekly-reports/week-04.md)          |
| 05   | 2025-12-05   | GitHub repo structure, README & early doc cleanup   | [week-05.md](weekly-reports/week-05.md)          |
| 06   | 2025-12-12   | SG13G2 PDK verification, local extraction attempt   | [week-06.md](weekly-reports/week-06.md)          |
| 07   | 2025-12-18   | PDK environment scripts, workspace setup & OA libs  | [week-07.md](weekly-reports/week-07.md)          |
| 08   | 2025-12-25   | Virtuoso launch attempts, environment debugging & disk issue resolution | [week-08.md](weekly-reports/week-08.md)          |

*Last updated: 26 January 2026*  
*Current status: PDK setup complete; Virtuoso environment blocked by VM disk quota — request for VM upgrade submitted.*

Feel free to contact me via GitHub Issues or email for questions, feedback, or collaboration.
