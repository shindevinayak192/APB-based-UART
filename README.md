# APB-based-UART
This repository contains the RTL implementation of a UART (Universal Asynchronous Receiver Transmitter) peripheral designed with an APB (Advanced Peripheral Bus) interface.

 -------------------------------------------------
I) Valid Operation Logic : Provides boundary protection. Prevents overflow and underflow.
 -------------------------------------------------
 assign push_valid = push && (!fifo_full || pop);
 assign pop_valid  = pop  && (!fifo_empty || push);

For these lines of code following conditions were considered:

**Case 1: FIFO is NORMAL (not full, not empty)**
fifo_full  = 0
fifo_empty = 0

  _Now evaluate all push/pop combinations._
  1. push=0, pop=0
  push_valid = 0 && (1 || 0) = 0
  pop_valid  = 0 && (1 || 0) = 0
  ✔ Nothing happens
  ✔ count unchanged
  
  2. push=1, pop=0
  push_valid = 1 && (1 || 0) = 1
  pop_valid  = 0 && (1 || 1) = 0
  ✔ Write occurs
  ✔ count++
  
  3. push=0, pop=1
  push_valid = 0 && (1 || 1) = 0
  pop_valid  = 1 && (1 || 0) = 1
  ✔ Read occurs
  ✔ count--
  
  4. push=1, pop=1
  push_valid = 1 && (1 || 1) = 1
  pop_valid  = 1 && (1 || 1) = 1
  ✔ Simultaneous write + read
  ✔ count unchanged
  
  _This is normal throughput behavior._

**Case 2: FIFO FULL**
fifo_full  = 1
fifo_empty = 0

  1. push=0, pop=0
  push_valid = 0
  pop_valid  = 0
  ✔ No change
  
  2. push=1, pop=0
  push_valid = 1 && (0 || 0) = 0
  pop_valid  = 0
  ❌ Push blocked
  ✔ Prevents overflow
  
  3. push=0, pop=1
  push_valid = 0
  pop_valid  = 1 && (1 || 0) = 1
  ✔ Pop allowed
  ✔ count--
  ✔ FIFO becomes not full next cycle
  
  4. push=1, pop=1
  push_valid = 1 && (0 || 1) = 1
  pop_valid  = 1 && (1 || 1) = 1
  ✔ Write allowed
  ✔ Read allowed
  ✔ count unchanged
  
  _Even though FIFO was full:_
  1.One entry removed
  2.One entry added
  3.No overflow
  
  -This maintains full throughput.

**Case 3: FIFO EMPTY**
fifo_full  = 0
fifo_empty = 1

  1. push=0, pop=0
  push_valid = 0
  pop_valid  = 0
  ✔ Nothing happens
  
  2. push=1, pop=0
  push_valid = 1 && (1 || 0) = 1
  pop_valid  = 0
  ✔ Write allowed
  ✔ count++
  
  3. push=0, pop=1
  push_valid = 0
  pop_valid  = 1 && (0 || 0) = 0
  ❌ Pop blocked
  ✔ Prevents underflow
  
  4. push=1, pop=1
  push_valid = 1 && (1 || 1) = 1
  pop_valid  = 1 && (0 || 1) = 1
  ✔ Write allowed
  ✔ Read allowed
  ✔ count unchanged
  
  _This is pass-through behavior._
  
  _The new data written is immediately read._

**II)**
    
