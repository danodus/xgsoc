Graphite
========

2D/3D accelerator.

After a reset, the frame buffer address is 0x01000000.

Registers
---------

=============== =============
Register        Address
=============== =============
GRAPHITE        BASE_IO + 32
=============== =============

GRAPHITE
^^^^^^^^

Read:

===== ============================
Field Description
===== ============================
[0]   Ready? 
===== ============================

Write:

====== ============================
Field  Description
====== ============================
[31:0] Command
====== ============================

The commands are documented here: https://danodus.github.io/graphite/.
