# UART-style USB slave model

`usb_slave_model.sv` extends the active bus agent and contains two directions:

- `send_packet(bytes, se0_bits)` and `respond_after_tx(bytes)` use the physical-line driver to send LS/FS USB SYNC, NRZI data, stuffed zeros and EOP into the DUT RX input through the resolved D+/D- bus and `analog_serial`. The model publishes each sent byte on `rxd_sent_ap`.
- Its `tx_wire_checker` listens to DUT `dp`, `dm`, and `tx_valid`. It checks every symbol against accepted SIE bytes, then independently decodes the observed symbols back into bytes, removes stuffing, and publishes them on `txd_rcvd_ap`. The environment connects both ports to the scoreboard, which compares decoded TX bytes against accepted SIE bytes and expected RX bytes against `DataOut`.

The TX path supports LS, FS and HS (including SOF EOP). The supplied CDR disables HS RX, so the slave only transmits toward DUT RX at LS and FS.
