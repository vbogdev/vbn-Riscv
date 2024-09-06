Temporary github repo for project.
Goal is to beat the rsd processor in area
Maybe also in power and frequency, definitely not in speed
Designed for Arty s25 dev board for 100 MHz clock, must be under 14k LUTs, preferably under 7k to avoid needing custom DDR3L interface, currently around 5k LUTs.

Stages:
  1. Fetch 1: predict new pc
  2. Fetch 2: access i-cache
  3. Fetch 3: i-cache tag comparison
  4. Decode
  5. Rename
  6. Issue
  7. Register read
  8. Execute (might be multiple ex stages)
  9. Mem access (if applicable, might be more mem stages)
  10. Write back
