# Simply Programmable microProcessor Device

## What is this?
It's a microprocessor emulator, for simple microprocessors. The cool bit is that you can invent your own with a DSL, let's call it SPuDLang.
Once you've described your processor in SPuDLang, this thing will run it.

## What's inside?

- `/standalone/ui`: a browser user interface (which can run in any browser environment). This also seems to have a jQuery plugin for the browser to render a fancy circuit board which lights up and makes sounds and things like that.
- `/standalone/emulator`: a flexible emulator backend with its own definition language for building any processor (InterpretedProcessor). This can be run in the browser, or as a coffeescript/nodejs library on the commandline.
- `/standalone/emulator/connection`: some different ways of passing messages from the browser UI to the emulator code. `Emu.coffee` is a good place to look to see that interface.
- Also, some glue to tie the browser stuff to an old OpenLearning system (the other top-level dirs that are not /standalone, i.e. /src, /media, etc.).

## How do SPuDLang?
Take a look in `/standalone/docs`, it has a grammar for the language. If you want to try it out in coffeescript on the commandline, there's an example for that at `/standalone/example4004.coffee`

A SPuD definition has 3 sections:
- it's name, register, and memory setup
- descriptions of the instructions
- how to execute the instructions

Instruction implementations in the 3rd section are of the form:

`<instruction number>, <number of bytes> <implementation>.`

Here's a definition:

    name: 4004
    memoryBitSize: 4
    numMemoryAddresses: 16
    registerBitSize: 4
    registerNames: IP, IS, R0, R1, SW
    [descriptions]
    0: Halt
    1: Increment R0 (R0 = R0 + 1)
    2: Decrement R0 (R0 = R0 - 1)
    3: Increment R1 (R1 = R1 + 1)
    4: Decrement R1 (R1 = R1 - 1)
    5: Add (R0 = R0 + R1)                           
    6: Subtract (R0 = R0 - R1)
    7: Print R0; Ring Bell
    8: Jump to address <data> if R0 != 0
    9: Jump to address <data> if R0 == 0
    10: Load <data> in to R0
    11: Load <data> in to R1
    12: Store R0 into address <data>
    13: Store R1 into address <data>
    14: Swap R0 and address <data>
    15: Swap R1 and address <data>
    [instructions]
    0, 1: halt.
    1, 1: R0++.
    2, 1: R0--.
    3, 1: R1++.
    4, 1: R1--.
    5, 1: R0 = R0 + R1.
    6, 1: R0 = R0 - R1.
    7, 1: print(R0); bell.
    8, 2 case R0 != 0: IP = [IP-1].
    9, 2 case R0 == 0: IP = [IP-1].
    10, 2: R0 = [IP-1].
    11, 2: R1 = [IP-1].
    12, 2: [[IP-1]] = R0.
    13, 2: [[IP-1]] = R1.
    14, 2: SW = [[IP-1]]; [[IP-1]] = R0; R0 = SW.
    15, 2: SW = [[IP-1]]; [[IP-1]] = R1; R1 = SW.
