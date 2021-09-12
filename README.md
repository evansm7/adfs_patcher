# Acorn ADFS 2.67 patcher module for IDE fixes

v0.2, 12 September 2021


Over on the stardot.org.uk forums, _sirbod_ has an excellent thread in which various ADFS 2.67 IDE problems are discussed and a patched ADFS provided.  See:

   * https://stardot.org.uk/forums/viewtopic.php?f=16&t=14016

The BASIC programs work on my system, but I wanted something I could push into my wonky IDE card's flash instead of forever loading a new ADFS (or BASIC patch program) from floppy.

This module is a small reimplementation of the tweaks in that thread, in a form that can easily be poked into many existing cards.  It's <1KB, so easily fits into empty space in my IDE card's flash.

If you can, it's much better to rebuild your host's ROM images with a better ADFS if possible, but this module is an alternative.


## How it works

On startup, the module:

   * Searches for ADFS
   * Moves ADFS to RMA/RAM
   * Iterates through a list of instructions to patch, and patches!

It should be safe to use on incompatible/unexpected ADFS versions; whilst I should really have looked for an ADFS checksum, the code at least looks for an 'expected' existing instruction at a given address before making alterations.

My hope is this doesn't render my IDE card "forever weird" when used in new machines. :)


## What it does

The following patches are currently applied:

   * Reduce max request size from 255 to 1
   * Increase timeout from 700 to 64K magic-time-units

These patches seem to make my CF card (in bog-standard CF-to-IDE adapter) work, instead of hang.  Bonus!


## Building

This uses `arm-none-eabi-gcc` and `arm-none-eabi-objcopy` (from gcc-arm-embedded), so have those in your path.  Then:

> make

This produces `patch_adfs_mod`.  This can be inserted into a Podule ROM image (using tools elsewhere).

The default build prints a bunch of diagnostics, such as ADFS's location and patch status, which will be seen at boot.  You may prefer a quiet build:

> make VERBOSE=0


## Future project ideas

   * Make this a generic utility, not just ADFS-specific, to add arbitrary module bug fixes live.
   * Add non-volatile RAM configuration options, e.g. to live-enable groups of patches.


## License

This code is MIT-licensed.


## Warranty

There is no (no) warranty supplied with this code.  It may hurt your machine, kill your data, or poison the minds of the naive.  Use it at your own risk (but enjoy it).


## Credits

Many thanks to Stardot, and _sirbod_ for the debug and ADFS RE.

This code is (c) 2021 Matt Evans.

