# AcademySoft TETRIS (1986) — reconstructed source code

**The original 1986 Soviet Tetris by A. Pajitnov & V. Gerasimov (AcademySoft, USSR)**  
Recovered by reverse engineering of the original `TETRIS.COM` (24245 bytes).  
Ported to **Turbo Pascal 7** (the original was written in Turbo Pascal 3.0).

---

## Legal notice

This project is a reconstruction of the original 1986 version of TETRIS distributed in the USSR.

- **Original game**: (C) 1986 Alexey Pajitnov, Vadim Gerasimov, AcademySoft (Computing Centre of the USSR Academy of Sciences), Moscow
- **Turbo Pascal runtime library**: (C) 1985 Borland International

**I publish this reconstruction strictly for historical, educational and archival purposes.**

This project is not affiliated with or endorsed by The Tetris Company. Please respect the intellectual property of the original authors.

If you represent the rights holders and want me to take this repository down, open an issue or contact me — I will do so.

---

## Requirements

The game runs **only under MS-DOS** (or a DOS emulator) — this is not a port to modern operating systems.

The code talks to IBM PC hardware directly:

- direct writes to video memory at `$B800` / `$B000` (screen save and restore);
- reads from the BIOS data area: `$0040:$0049` (video mode) and `$0040:$0060` (cursor shape);
- `INT 10h` for cursor control;
- switching between 40- and 80-column text modes and monochrome MDA;
- real-mode `Crt` unit: `Sound`, `Delay`, `ReadKey`;
- the 6-byte Turbo Pascal `Real` type, which the high score file format depends on.

It will not run natively on Windows or Linux.

## Building and running

### Option A: DOSBox + Turbo Pascal 7 (recommended)

1. Install [DOSBox](https://www.dosbox.com/) (or DOSBox-X / DOSBox Staging) with Turbo Pascal 7.
2. Compile the source with the command-line compiler:
