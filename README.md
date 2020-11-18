# Coco-Ibex

Repo which contains the design of the secured Ibex core, as shown in [COCO: Co-Design and Co-Verification of Masked Software Implementations onCPUs](https://eprint.iacr.org/2020/1294.pdf). 

The design is based on commit #863fb56eb166d of the [original Ibex core](https://github.com/lowRISC/ibex).

## Structure

* **rtl**: contains the hardware design of the modified Ibex core.
  * secure.sv: allows to enable/disable certain security features
  * 
* **shared/rtl**: contains the secure RAM implementation

### Enabling/disabling security features
We implemented the following security features:
* `REGREAD_SECURE`: gating mechanism for reads from the register file
* `REGWRITE_SECURE`: gating mechanism for writes to the register file
* `MEM_SECURE`: use secure RAM
* `MD_SECURE`: gating mechanism for multiplication unit
* `SHIFT_SECURE`: gating mechanism for shifter in ALU
* `ADDER_SECURE`: gating mechanism for adder in ALU
* `CSR_SECURE`: gating mechanism for CSR unit



Each of these features is standalone, i.e., disabling `REGREAD_SECURE` but enabling all other features will still work. Disabling can be done by **uncommenting** the respective line in secure.sv.

We did not add an enabling/disabling mechanism for clearing the hidden LSU state.

### Configuring secure RAM
Configurations can be made by altering `a` and `b` in ram_1p_secure.v:
* `a`: number of 32-bit cells per block
* `b`: number of blocks

In-block addressing is done using one-hot encoded addresses.