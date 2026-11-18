# USB 2.0 PHY UVM Structural Testbench Skeleton

## 1. Scope

This is a reusable **structural UVM skeleton** for a digital USB 2.0 PHY. It contains:
- DUT-facing PHY/SIE interface and PHY agent
- External USB Host/Device digital BFM agent
- Resolved DP/DM bus abstraction
- PHY and bus monitors
- Scoreboard analysis FIFOs for observed pin-level snapshots
- UVM environment, configuration objects, and base test
- Dedicated LS, FS, and HS test classes
- Cadence Xcelium file list, Makefile, and run script


## 2. Architecture

```text
tb_top
 +-- usb2_phy_top (temporary stub until RTL arrives)
 +-- usb_phy_if
 +-- usb_bus_if (resolved digital DP/DM)
 +-- usb_phy_base_test
      +-- usb_phy_env
           +-- phy_agent
           |    +-- phy_sequencer
           |    +-- phy_driver (idle; no sequences)
           |    +-- phy_monitor
           +-- usb_bfm_agent
           |    +-- usb_bfm_sequencer
           |    +-- usb_bfm_driver (idle; no sequences)
           |    +-- usb_bfm_monitor
           +-- usb_phy_scoreboard (observation FIFOs only)
```

The PHY agent represents the digital SIE-facing side. The BFM agent represents the external participant connected to DP/DM. The BFM is only a digital bus participant at this stage; it is not a complete USB Host/Device controller.

## 3. Top-level interface from architecture

| Signal          | DUT direction | Width |
|---              |---:           |---:|
| `clk`           | Input         | 1 |
| `rst_n`         | Input         | 1 |
| `usb_speed`     | Input         | 2 |
| `sof_packet`    | Input         | 1 |
| `sie_valid`     | Input         | 1 |
| `sie_data`      | Input         | 8 |
| `sop`           | Input         | 1 |
| `eop`           | Input         | 1 |
| `sie_ready`     | Output        | 1 |
| `tx_line_state` | Output        | 2 |
| `tx_valid`      | Output        | 1 |
| `rx_dp`, `rx_dm`| Input         | 1 each |
| `Rx_data`       | Output        | 8 |
| `Rx_valid`      | Output        | 1 |
| `line_state`    | Output        | 2 |

These are architecture-level recommended names, not confirmed RTL port declarations. Case-sensitive names such as `Rx_data` and `Rx_valid` must be checked against the RTL.

## 4. Speed modes

The testbench uses the following two-bit encoding from the architecture interface:

| `usb_speed` | Enum | Mode | Nominal signaling rate |
|---|---|---|---:|
| `2'b00` | `USB_SPEED_LS` | Low Speed | 1.5 Mbit/s |
| `2'b01` | `USB_SPEED_FS` | Full Speed | 12 Mbit/s |
| `2'b10` | `USB_SPEED_HS` | High Speed | 480 Mbit/s |
| `2'b11` | `USB_SPEED_RESERVED` | Reserved | Do not select |

Dedicated tests are registered:
- `usb_phy_ls_test`
- `usb_phy_fs_test`
- `usb_phy_hs_test`

Run them individually:

```bash

xrun -uvm -f filelist.f +USB_SPEED=0

    // Configure selected speed
    case (speed_arg)

      0: env_cfg.speed = USB_SPEED_LS;
      1: env_cfg.speed = USB_SPEED_FS;
      2: env_cfg.speed = USB_SPEED_HS;


make run TEST=usb_phy_ls_test
make run TEST=usb_phy_fs_test
make run TEST=usb_phy_hs_test
```

The selected test sets **all three places consistently**:
1. `phy_if.usb_speed` (DUT input)
2. `usb_bus_if.usb_speed` (bus monitor context)
3. PHY and BFM agent configuration objects

This fixes the earlier configuration mismatch in which the BFM could be configured for LS/HS while the DUT remained statically set to FS.

Speed configuration is applied before UVM run phase. This skeleton does not implement legal run-time speed negotiation or speed switching during a packet.

## 5. Role configuration

`usb_role_e` describes the external BFM role:
- `USB_ROLE_HOST`
- `USB_ROLE_DEVICE`

This is a context setting only. No host/device protocol engine is implemented. Set the BFM role to the participant opposite the DUT's role when that distinction matters to your architecture.

## 6. Digital DP/DM bus ownership

`usb_bus_if` contains resolved `tri` nets:
- DUT drives when `dut_drive_en` is asserted.
- External BFM drives when `ext_drive_en` is asserted.
- A disabled side releases the bus using `Z`.
- If both sides drive, the monitor reports `USB_BUS_CONTENTION`.

The DUT drive enable is provisionally tied to `phy_if.tx_valid`. Confirm that `tx_valid` really means line-driver enable in the RTL. The bus model does not model analog voltage, termination, receiver thresholds, slew, HS current-mode signaling, or electrical compliance.

## 7. Compile and run with Cadence Xcelium

Requirements:
- `xrun` in `PATH`
- UVM support available in the Xcelium installation

From `sim/`:

```bash
make compile
make run
make run TEST=usb_phy_ls_test SEED=10
make run TEST=usb_phy_fs_test SEED=20
make run TEST=usb_phy_hs_test SEED=30
make run DUMP=0
make clean
```

Or:

```bash
./run_sim.sh
```

`make compile` and `make run` are provided, but this package has **not been compiled against your local Xcelium installation**. Tool-version-specific command-line adjustments may be needed.

## 8. Expected behavior with the placeholder stub

The structural test should construct the environment, connect the agents and analysis FIFOs, hold reset, run for a short interval, and finish. The stub ties outputs off. Therefore:
- `sie_ready` remains low
- `tx_valid` remains low
- TX line state remains `2'b00`
- RX outputs remain zero

These values are stub tie-offs, not expected USB PHY behavior.

## 9. File organization

```text
usb2_phy_uvm/
  rtl/
    usb2_phy_top_stub.sv
  tb/
    tb_top.sv
    usb_phy_if.sv
    usb_bus_if.sv
    usb_phy_pkg.sv
  agent/
    phy_agent/
    usb_bfm_agent/
  env/
    usb_phy_env.sv
    usb_phy_env_config.sv
    usb_phy_scoreboard.sv
  tests/
    usb_phy_base_test.sv
  sim/
    filelist.f
    Makefile
    run_sim.sh
  README.md
```

## 10. Integration checklist when RTL arrives

1. Replace `usb2_phy_top_stub.sv` with the real RTL source list.
2. Confirm DUT module and every port name, direction, width, and case.
3. Confirm clock frequency and reset polarity/sequence.
4. Confirm `usb_speed` encoding and when it may change.
5. Confirm `tx_line_state` bit-to-pin mapping and `tx_valid` semantics.
6. Confirm DP/DM input boundary and whether an analog/transceiver model is required.
7. Confirm external bus idle, J/K, SE0/SE1 and output-enable behavior for LS/FS/HS.
8. Confirm whether `sof_packet`, `sop`, and `eop` are pulses, levels, or handshake-qualified controls.
9. Compile with the actual RTL and fix interface mismatches before adding sequences.
10. Only then add packet-level stimulus, reference models, assertions, coverage, and constrained-random tests.


