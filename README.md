# UART Design and Verification

## Introduction

This project implements a parameterized Universal Asynchronous Receiver Transmitter (UART) in Verilog HDL. It performs serial data communication between two devices without a shared clock signal, supporting configurable baud rates and data word lengths. The UART serializes parallel data for transmission and deserializes received serial data back into parallel form, conforming to the 8N1 serial frame format.

## Objectives

- Design and implement a synthesizable Verilog HDL model for serial data transmission and reception
- Develop a self-checking testbench and behavioral reference model for functional verification
- Verify normal and corner case scenarios including false start rejection, bad stop bit handling, mid-transmission reset, and signal complementarity
- Validate functionality using simulation and coverage analysis techniques

## Design Architecture

The DUT is a synchronous UART with separate transmitter and receiver modules driven by a shared 16x oversampling baud rate clock. Both transmitter and receiver follow a four-state FSM: **IDLE → START → DATA → STOP**. The receiver includes an additional false start detection mechanism at the center of the start bit.

### Parameters

| Parameter | Default | Supported Values | Description |
|-----------|---------|-----------------|-------------|
| b | 8 | 6, 7, 8 | Data word length in bits |
| br | 2400 | 1200, 2400, 9600, 19200 | Baud rate in symbols/second |
| clk_freq | 50000000 | Any | System clock frequency in Hz |

### Inputs

| Signal | Width | Description |
|--------|-------|-------------|
| sys_clk | 1 | Main system clock |
| sys_rst_l | 1 | Active low asynchronous reset |
| xmitH | 1 | Active high pulse to start transmission |
| xmit_dataH | b | Parallel data to be transmitted |
| uart_REC_dataH | 1 | Asynchronous serial input from remote transmitter |

### Outputs

| Signal | Width | Description |
|--------|-------|-------------|
| uart_XMIT_dataH | 1 | Serial output of the transmitter |
| xmit_active | 1 | High during active transmission |
| xmit_doneH | 1 | Complement of xmit_active; high when idle |
| rec_dataH | b | Deserialized received data |
| rec_busy | 1 | High while receiver is active |
| rec_readyH | 1 | Complement of rec_busy; high when idle |

## Frame Format

Each data packet follows the 8N1 format transmitted LSB first:

| Field | Logic Level | Duration |
|-------|-------------|----------|
| Idle line | 1 | Until xmitH asserted |
| Start bit | 0 | 16 baud clock ticks |
| Data bits | LSB to MSB | 16 ticks per bit |
| Stop bit | 1 | 16 baud clock ticks |

## Verification

The testbench uses a **dual-instantiation self-checking architecture**. Both the DUT (`uart_top`) and a behavioral reference model (`uart_ref_model`) receive identical stimulus simultaneously. Outputs are compared after each test and a PASS/FAIL result is reported.

### Test Tasks

| Task | Description |
|------|-------------|
| send_byte | Transmits data in loopback and waits for completion |
| send_with_framing_error | Forces stop bit to 0 to trigger error assertion |
| compare_with_ref | Compares all DUT outputs against the reference model |
| do_reset | Verifies clean recovery after reset |

### Simulation Results

- **77 test vectors** applied — all passed
- 100% statement, toggle, FSM state, and FSM transition coverage
- ~98% branch coverage
- Overall coverage: **99.5%**

## Tools Used

- **Questa SIM** — RTL simulation, waveform analysis, and coverage generation
- **Vivado** — Verilog design development and RTL analysis

## Conclusion

The UART was successfully designed and verified for serial communication at 9600 baud with 8-bit data word length. The design correctly handles transmitter serialization, receiver deserialization, false start rejection, and framing error detection. The self-checking testbench and reference model validated functionality across directed, corner case, and FSM coverage scenarios.
