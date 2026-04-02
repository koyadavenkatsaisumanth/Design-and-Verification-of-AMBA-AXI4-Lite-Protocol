# Design-and-Verification-of-AMBA-AXI4-Lite-Protocol
## Overview
This project focuses on the design and verification of an AXI4-Lite master-slave system using SystemVerilog. The implementation covers all five AXI4-Lite channels, including write address, write data, write response, read address, and read data, ensuring proper VALID-READY handshake behavior throughout. A register-based slave model was developed with support for different response types such as OKAY, SLVERR, and DECERR. On the verification side, a self-checking testbench was built using reusable read and write tasks to validate both normal and edge-case scenarios, including mixed transactions and error conditions. The design was simulated using QuestaSim, and all 42 directed test cases passed successfully, confirming correct protocol functionality and data integrity. This project also involved debugging handshake timing issues and integrating all components into a cohesive system, providing hands-on experience with class-based verification and protocol-level validation.
## My Contribution
As part of a group of four members, where we collaboratively worked on both the design and verification of the AXI4-Lite protocol. As part of my contribution, I primarily focused on developing the testbench and integrating the overall system, ensuring proper interaction between the master and slave components. I implemented reusable read and write tasks to efficiently generate stimulus and validate different transaction scenarios, including normal operations as well as error conditions like SLVERR and DECERR. In addition, I contributed to a portion of the slave design, particularly in handling specific logic and ensuring correct protocol behavior. I was also involved in debugging issues related to handshake timing and data mismatches during simulation, which helped in achieving correct functionality across all test cases.
## Project Structure
src/        → Design files  
tb/         → Testbench  
scripts/    → Simulation scripts  
docs/       → Report & presentation  
waveforms/  → Simulation results  
