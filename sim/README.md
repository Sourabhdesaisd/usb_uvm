# Run with Xcelium

Requires Cadence Xcelium `xrun` with SystemVerilog and UVM 1.2 compatible support and covergroups. From `sim/`:

```sh
make compile
make run TEST=usb_phy_full_path_test USB_SPEED=1
make run TEST=usb_phy_full_path_test USB_SPEED=2
make run TEST=usb_phy_fault_test USB_SPEED=0 FAULT=2
make run TEST=usb_phy_reset_test USB_SPEED=1 RESET_CASE=2
make regression
```

`USB_SPEED=0/1/2` selects LS/FS/HS; use HS only for TX and reset tests. `FAULT=1/2/3/4` chooses SE1/missing stuff/long SE0/broken SYNC; faults are LS/FS only. `RESET_CASE=0/1/2` selects initialization/during TX/during RX; RX reset is LS/FS only. `make regression` launches each applicable combination, writing separate `logs/*.log`; the first failure stops the Make target. `make -n regression` prints commands without running. Check UVM_ERROR/UVM_FATAL totals, wire checker packet counters, RX scoreboard checks and actual coverage report before marking results Passed. No simulator was available during creation, so compile and run status is Pending.

The filelist references the included RTL by relative path. Do not mix these files with another version of the same modules; substitute your production RTL in `filelist.f` if needed. Keep WIDTH=8 and 480 MHz defaults unless the TB parameters and timing functions are updated together.
