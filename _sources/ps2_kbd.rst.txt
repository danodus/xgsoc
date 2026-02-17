PS/2 Keyboard
=============

PS/2 keyboard.

Registers
---------

=============== =============
Register        Address
=============== =============
KEYBOARD_DATA   BASE_IO + 24
KEYBOARD_STATUS BASE_IO + 28
=============== =============

KEYBOARD_STATUS
^^^^^^^^^^^^^^^

Read:

===== ============================
Field Description
===== ============================
[0]   Key available? 
===== ============================

Write: -

KEYBOARD_DATA
^^^^^^^^^^^^^

Read:

====== ============================
Field  Description
====== ============================
[7:0]  Character
====== ============================

Write: -
