# USB 2.0 PHY UVM environment

This project retains the attached UART bench's folder structure. `phy_agent/` contains the USB SIE byte agent (the PHY has no phy port); `phy_bfm_agent/` contains the active USB line peer, `env/` contains top, scoreboard, wire oracle and coverage, `rtl/` contains supplied DUT plus interfaces, `test/` contains directed tests, `test_pkg/` contains the UVM package, and `sim/` contains Xcelium commands.

The peer drives received SYNC/NRZI/stuffed payload/EOP through the resolved D+/D- analog front-end pins and separately listens to DUT TX pins. The TX oracle constructs symbols from accepted SIE handshakes, compares line symbols and duration, decodes bytes independently, then the scoreboard compares bytes and packet tags. On RX, expected bytes are published by the peer before it drives SYNC; the scoreboard checks actual DataOut and SOP/EOP and status events. See `SLAVE_MODEL_README.md` and `TESTPLAN.md`.



## Transaction logs

Default `UVM_MEDIUM` verbosity prints `USB_PEER_PACKET` / `USB_PEER_DATA` for intended device data, `USB_RX_EXPECT` for the queued receive oracle, `USB_TX_SIE` for bytes accepted by the PHY transmitter, and `USB_SLAVE_SENT` for bytes scheduled by the peer. `USB_TX_COMPARE` and `USB_RX_COMPARE` print every expected and actual byte with `MATCH` or `MISMATCH`, speed, SOP and EOP. `USB_RX_UNSCORED` labels fault stimulus for which no expected byte was supplied. `USB_RX_STATUS` prints observed flags and configured error expectations. `USB_TX_WIRE` reports packet-level timing and line-symbol match results; symbol mismatches also produce `UVM_ERROR` with the symbol index and expected/actual D+/D− levels. Logs are event-based, so there is no per-system-clock message flood. In `sim/`, use `make run TEST=usb_phy_full_path_test USB_SPEED=1 UVM_VERBOSITY=UVM_MEDIUM`; inspect `logs/*.log` and search for `USB_TX_COMPARE|USB_RX_COMPARE|MISMATCH|UVM_ERROR`. No simulator was available here, so these messages have not yet been observed in a run.
