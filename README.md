# Numerically_Controlled_Oscillator

A lightweight, hardware-friendly oscillator using the **CORDIC (Coordinate Rotation Digital Computer)** algorithm to generate high-precision sine and cosine waveforms without multipliers.  
Perfect for FPGA, ASIC, or embedded DSP designs where resource efficiency is critical.

---

## 🚀 Features
- **Fully multiplier-free** design using iterative vector rotations
- **Fixed-point arithmetic** for speed and hardware compatibility
- Generates **sine and cosine** signals simultaneously
- **Scalable precision** by adjusting iteration depth
- Verified through **simulation and FPGA testing**

---

## 📂 Repository Structure

/src → HDL source files (VHDL)
cordic_oscillator.vhd
cordic_pipelined.vhd
cordic_pkg.vhd
cordic_stage.vhd
/sim → Testbenches and simulation scripts
/docs → Diagrams, theory notes, and performance results
