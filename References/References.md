# References

Complete list of references cited in the project report:
*Digital Design of a CNN Accelerator on ASIC (IHP SG13G2 130 nm)*

---

## [1]–[3] Open-Source PDK & Lab Resources

| Ref | Description | Link |
|-----|-------------|------|
| [1] | IHP-GmbH, IHP Open Source PDK – SG13G2 130 nm BiCMOS | https://github.com/IHP-GmbH/IHP-Open-PDK |
| [2] | IHP-GmbH, SG13G2 Open Source Process Specification | https://github.com/IHP-GmbH/IHP-Open-PDK |
| [3] | F. Aschauer, DD_Lab_exercise – OTH Regensburg | https://github.com/baruaeee/DD_Lab_exercise |

---

## [4]–[6] Cadence Tool Documentation (Internal Access)

These are commercial tools — manuals are accessible via university license only.

| Ref | Tool | Version |
|-----|------|---------|
| [4] | Cadence Xcelium Logic Simulator – User Guide | v24.03 (2024) |
| [5] | Cadence Genus Synthesis Solution – User Guide | v23.11 (2024) |
| [6] | Cadence Innovus Implementation System – User Guide | v23.31 (2024) |

---

## [7]–[9] Academic Papers

| Ref | Citation | Link |
|-----|----------|------|
| [7] | LeCun et al., "Gradient-Based Learning Applied to Document Recognition," *Proc. IEEE*, vol. 86, no. 11, pp. 2278–2324, 1998. | [IEEE](https://ieeexplore.ieee.org/document/726791) / [PDF](http://yann.lecun.com/exdb/publis/pdf/lecun-01a.pdf) |
| [8] | Sze et al., "Efficient Processing of Deep Neural Networks: A Tutorial and Survey," *Proc. IEEE*, vol. 105, no. 12, pp. 2295–2329, 2017. | [IEEE](https://ieeexplore.ieee.org/document/8114708) / [arXiv](https://arxiv.org/abs/1703.09039) |
| [9] | Jacob et al., "Quantization and Training of Neural Networks for Efficient Integer-Arithmetic-Only Inference," *CVPR 2018*, pp. 2704–2713. | [arXiv](https://arxiv.org/abs/1712.05877) |

> PDFs for [7] and [8] require IEEE Xplore access. [9] is freely available on arXiv.

---

## [10] Textbook

| Ref | Citation |
|-----|----------|
| [10] | N. H. E. Weste and D. M. Harris, *CMOS VLSI Design: A Circuits and Systems Perspective*, 4th ed. Boston, MA: Addison-Wesley, 2011. |

---

## [11] IEEE Standard

| Ref | Standard |
|-----|----------|
| [11] | IEEE Std 1800-2017 – *IEEE Standard for SystemVerilog: Unified Hardware Design, Specification, and Verification Language*, 2017. |

---

## [12]–[15] This Repository (Self-References)

| Ref | Content | Path in Repo |
|-----|---------|--------------|
| [12] | RTL source, synthesis & P&R reports, weekly progress | root of this repo |
| [13] | Genus area report (`area.rpt`), Innovus P&R log, timing reports | `Cadence/Genus/Final_Genus_Out/reports/` and `Cadence/Innovus/` |
| [14] | Floorplan screenshot, final post-route layout screenshot | captured from Innovus 23.31 GUI, June 2026 |
| [15] | Simplified dataflow block diagram (`BlockDiagram.png`) | June 2026 |