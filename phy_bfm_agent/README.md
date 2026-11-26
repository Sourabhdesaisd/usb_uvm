# UART-style USB slave model

`usb_slave_model.sv` extends the active bus agent and contains two directions:

- `send_packet(bytes, se0_bits, hs_sof_eop)` and `respond_after_tx(bytes)` use the physical-line driver to send LS/FS/HS USB SYNC, NRZI data, stuffed zeros and EOP into the DUT RX pins through the resolved D+/D- bus. `send_fault_packet(bytes, fault_kind)` also generates malformed PHY traffic. At LS/FS the model publishes expected received bytes on `rxd_sent_ap`; at HS this comparison is disabled until the DUT has an HS RX source.
- Its `tx_wire_checker` listens to DUT `dp`, `dm`, and `tx_valid`. It checks every symbol against accepted SIE bytes, then independently decodes the observed symbols back into bytes, removes stuffing, and publishes them on `txd_rcvd_ap`. The environment connects both ports to the scoreboard, which compares decoded TX bytes against accepted SIE bytes and expected RX bytes against `DataOut`.

The peer sends and checks line traffic at LS, FS and HS, including the HS SOF EOP and a response after DUT TX. The supplied CDR disables HS RX: the peer can drive HS pins, but this DUT cannot provide decoded HS RX bytes. Use `usb_phy_hs_peer_test` at `USB_SPEED=2` for the supported HS boundary exercise.
