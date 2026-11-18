# USB 2.0 PHY UVM Simulation  README

## 1. Overview

This README describes how to compile, elaborate and run USB 2.0 PHY UVM simulations using Cadence Xcelium.

The testbench supports three USB 2.0 speed modes:

- Low Speed (LS)
- Full Speed (FS)
- High Speed (HS)

Separate UVM tests are used for each speed mode.

## 2. Compile and Elaborate Using Makefile

```bash
make compile
```

## 3. Simulation Using Makefile

### Low Speed (LS)

```bash
make run TEST=usb_phy_ls_test
```

Shortcut:

```bash
make run_ls
```

### Full Speed (FS)

```bash
make run TEST=usb_phy_fs_test
```

Shortcut:

```bash
make run_fs
```

### High Speed (HS)

```bash
make run TEST=usb_phy_hs_test
```

Shortcut:

```bash
make run_hs
```

## 4. Direct Simulation Using Xcelium (xrun)

Simulation can also be executed directly using the Xcelium command without the Makefile.

### 4.1 Low Speed (LS)

```bash
xrun -64bit -uvm -sv -access +rwc \
-f filelist.f \
-top tb_top \
+UVM_TESTNAME=usb_phy_ls_test \
-l usb_phy_ls.log
```

### 4.2 Full Speed (FS)

```bash
xrun -64bit -uvm -sv -access +rwc \
-f filelist.f \
-top tb_top \
+UVM_TESTNAME=usb_phy_fs_test \
-l usb_phy_fs.log
```

### 4.3 High Speed (HS)

```bash
xrun -64bit -uvm -sv -access +rwc \
-f filelist.f \
-top tb_top \
+UVM_TESTNAME=usb_phy_hs_test \
-l usb_phy_hs.log
```
.

## 5. Simulation with Different Random Seeds

A different seed can be specified using `-seed`.

Example using Makefile:

```bash
make run TEST=usb_phy_fs_test SEED=10
```

Example using direct Xcelium:

```bash
xrun -64bit -uvm -sv -access +rwc \
-f filelist.f \
-top tb_top \
+UVM_TESTNAME=usb_phy_fs_test \
-seed 10 \
-l usb_phy_fs_seed10.log
```



## 6. Simulation Workflow

### Using Makefile

```bash
make compile
make run_ls
make run_fs
make run_hs
```

### Using Direct Xcelium Commands

```bash
xrun -64bit -uvm -sv -access +rwc -f filelist.f -top tb_top +UVM_TESTNAME=usb_phy_ls_test -l usb_phy_ls.log

xrun -64bit -uvm -sv -access +rwc -f filelist.f -top tb_top +UVM_TESTNAME=usb_phy_fs_test -l usb_phy_fs.log

xrun -64bit -uvm -sv -access +rwc -f filelist.f -top tb_top +UVM_TESTNAME=usb_phy_hs_test -l usb_phy_hs.log
```


