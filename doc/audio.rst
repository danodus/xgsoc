PCM Audio
=========

48 kHz stereo PCM played on the HDMI port. Enable it with configuration letter ``a`` together with video (``v``). The minimum configuration is ``bva``.

Every video build uses this transmitter. Without ``a`` it emits DVI, and the PCM register is left out.

Registers
---------

=========== =============
Register    Address
=========== =============
PCM         BASE_IO + 60
=========== =============

PCM
^^^

Read:

====== ============================
Field  Description
====== ============================
[0]    1 = a sample can be written
====== ============================

Write:

========== ============================
Field      Description
========== ============================
[15:0]     Left sample, signed 16-bit
[31:16]    Right sample, signed 16-bit
========== ============================

A write while the FIFO is full is ignored. Poll bit 0 before each sample. The playback rate is 48 kHz.

``HW_CONFIG`` bit 5 is set when audio is compiled in.
