Temporary github repo for project.
Goal is to beat the rsd processor in area
Maybe also in power and frequency, definitely not in speed
Designed for Arty s25 dev board for 80 MHz clock, must be under 14k LUTs, preferably under 7k to avoid needing custom DDR3L interface, currently around 5k LUTs (prefetcher, branch predictor, and caches are currently being reworked, simulation uses simple model for each of these to allow for simulations).
Most interesting aspects of this project at the moment in my opinion is the register file, the issue queues, and the renaming stage, in this order.

Stages:
  1. Fetch 1: predict new pc (currently being reworked)
  2. Fetch 2: access i-cache (currently being reworked)
  3. Fetch 3: i-cache tag comparison (currently being reworked)
  4. Decode
  5. Rename
  6. Issue
  7. Register read
  8. Execute (might be multiple ex stages)
  9. Mem access (if applicable, might be more mem stages)
  10. Write back (possibly 2 write back stages)


Design:
- For now, fetch and branch prediction is being reworked, so the design assumes the cache is made of infinite numbers of flip flops. Branch predictor assumes branch is never taken. These are currently being redone.
- Renaming scheme is pretty similar to mips r10k, with a queue for checkpointing. Interesting part of renaming unit is that checkpoint unit, uses distributed ram to store checkpoints (which stores old pointers for active list, the old rmt mappings, and the busy bit table), which makes the renaming unit significantly smaller.
- Issue queues are also optimized for area. Arithmetic out of order IQ is split into 2 banks. The reason for this is that most of the instruction's data is store in distributed ram, which allows 1 read/write per cycle (which can be increased to 2 by using the negative edge for writing and the positive edge for reading), which means that 1 instruction can enter and 1 can exit per cycle in each bank. This does limit out-of-ordery-ness, and in the future, I will rework this to run on a 160 MHz clock, so that there are no banks. A similar approach was used for the in order issue queue, which uses distributed ram banks. However, since instructions are done in order the banks do not significantly slow performance.
- Register read stage is probably one of the most optimized stages. First, the register file is made with block ram modules. Additionally, 4 BRAMS are used, which are gauranteed to have the same data. This stage runs on a 240 MHz clock (3 times higher than the rest of the processor). For each 80 MHz cycle, the first 2 240 MHz cycles are used for writing data to the register file. Since each BRAM has 2 ports, 4 writes can be done. Each BRAM will have the same data inputted, to ensure consistency between each bank. The final 240 MHz cycle is used for writing. Since there are 4 banks, there are 4*2=8 reads available, meaning this processor can do 4 writes, 8 reads per 80 MHz cycle, while also having an incredibly tiny footprint (148 LUTs/1.01%, 728 slice regs/2.49%, 4 BRAMS/8.89%).
- The execute stage is nothing special. 
- The Memory access stage is placeholder for now.
- The write back stage currently a single cycle. A seperate version which uses 2 stages, where the first stage writes back to the reg file, and the second stage writes back to the rename stage. This was used for lower slack, as the frequency bottleneck is from the path from the arith/mem stage output to the first register file write back (reg file is on the 240 MHz clock domain, which results in a small timing budget). The 2 stage Writeback has a lower fanout for this specific path, which allows for a slightly higher frequency. However, because of the low frequency clock used on the Arty s25 board, the jitter is about 1.1 ns for the 240 MHz clock, which makes timing very difficult. This can allow a slightly higher frequency (90 MHz/270 MHz) because of the lower net delay, however, this would also lead to a higher misprediction penalty, so further testing will be needed to determine which is better.
