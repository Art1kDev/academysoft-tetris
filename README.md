# AcademySoft TETRIS (1986) — reverse-engineered source code

**Reverse-engineered reconstruction of the original 1986 Soviet Tetris by A. Pajitnov & V. Gerasimov (AcademySoft, USSR).**

The source code was recovered by reverse engineering the original `TETRIS.COM` executable (24245 bytes). The reconstruction preserves the original program structure, procedures, variables, algorithms and formulas.

The original program was written in **Turbo Pascal 3.0**. I ported the reconstructed source code to **Turbo Pascal 7.0** while keeping its original DOS-specific behavior.

---

## Legal notice

This repository contains a reverse-engineered reconstruction of the original 1986 version of TETRIS distributed in the USSR.

- **Original game**: (C) 1986 Alexey Pajitnov, Vadim Gerasimov, AcademySoft (Computing Centre of the USSR Academy of Sciences), Moscow
- **Turbo Pascal runtime library**: (C) 1985 Borland International

**I publish this reconstruction strictly for historical, educational and archival purposes.**

This project is not affiliated with or endorsed by The Tetris Company. Please respect the intellectual property rights of the original authors and other rights holders.

If you represent the rights holders and want me to take this repository down, open an issue or contact me.

---

## Requirements

The game runs **only under MS-DOS** (or a DOS emulator). This is not a port to a modern operating system.

The reconstructed code retains direct interaction with IBM PC hardware:

- direct access to video memory at `$B800` / `$B000`;
- access to the BIOS Data Area;
- BIOS `INT 10h` services;
- 40/80-column and MDA text modes;
- Turbo Pascal `Crt` routines (`Sound`, `Delay`, `ReadKey`);
- the 6-byte Turbo Pascal `Real` type used by the original high-score format.

## Building and running

### DOSBox + Turbo Pascal 7

Install DOSBox (or DOSBox-X / DOSBox Staging) and Turbo Pascal 7.0, then compile the reconstructed source.
