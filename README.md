Temporary github repo for project.
Goal is to beat the rsd processor in area
Maybe also in power and frequency, definitely not in speed
Currently first 2 stages are working (fetch and decode), although decode is untested and fetch is only a little tested
Designed for Arty s25 dev board for 100 MHz clock

Architectural decisions to keep in mind for later stages:
  -branch_fb[0] TAKES PRECEDENCE OVER branch_fb[1] --> means it is older in the active list
  -JALR will be treated as a usually incorrect branch --> NO DECODE FEEDBACK 
  -JALR will stored the value that will be stored in rd in the decode_ifc.target, as imm is taken --> In ex stage, a mux will be needed
  -currently no prediction in decode stage --> add second more accurate predictor here?


