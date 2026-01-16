Configuration
=============

System configuration.

Registers
---------

=============== =============
Register        Address
=============== =============
CONFIG          BASE_IO + 36
FB_ADDR         BASE_IO + 40
VSYNC           BASE_IO + 44
HW_CONFIG       BASE_IO + 56
=============== =============

CONFIG
^^^^^^

Read:

======= ============================
Field   Description
======= ============================
[15:0]  Vertical video resolution
[31:16] Horizontal video resolution
======= ============================

Write:

======= ============================
Field   Description
======= ============================
[0]     0=no action, 1=flush cache
======= ============================


FB_ADDR
^^^^^^^

Read:

======= ============================
Field   Description
======= ============================
[31:0]  Frame buffer address
======= ============================

Write:

======= ============================
Field   Description
======= ============================
[31:0]  Frame buffer address
======= ============================

VSYNC
^^^^^

Read:

======= ============================
Field   Description
======= ============================
[0]     VSYNC?
======= ============================

Write: -

HW_CONFIG
^^^^^^^^^

Read:

======= ============================
Field   Description
======= ============================
[0]     Is video available?
[1]     Is PS/2 keyboard available?
[2]     Is PS/2 mouse available?
[3]     Is USB host available?
[4]     Is Graphite available?
[31]    Is simulation?
======= ============================

Write: -