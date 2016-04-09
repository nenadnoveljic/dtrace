#!/usr/sbin/dtrace -sC

/* 
 * emlxsoverhead.d v1.1
 *
 * The scripts measures the the I/O processing time in the Emulex driver code.
 * For more information see:
 * http://nenadnoveljic.com/blog/emulex-hba-driver-performance-analysis-measuring-overhead
 * 
 * Author:    Nenad Noveljic
 *
 * Usage:     emlxsoverhead.d [threshold(us)]
 * Example:   emlxsoverhead.d 100
 *
 * Input:
 *    threshold(us) - if specified only I/Os that last
 *                    longer than threshold[us] will be tracked
 * 
 * Output:
 *    TIMESTAMP:     time when I/O was performed
 *    TOTAL(us):     I/O latency measured on the driver
 *    EMLXS(us):     overhead of the driver code
 *    I/O START(us): duration of the I/O start stage
 *    I/O INTR(us):  time spent in the interrupt handler
 *    QUEUE(us):     time spent on the completion queue
 *    I/O DONE:      time spent on the completion thread
 *
 * Copyright: (c) Nenad Noveljic - All rights reserved
 *
*/


#pragma D option quiet 
#pragma D option defaultargs
#pragma D option dynvarsize=2M

BEGIN
{
  threshold = $1 * 1000 ;
  printf("%-20s %-16s %-16s %-16s %-16s %-16s %-16s \n", \
    "TIMESTAMP","TOTAL(us)","EMLXS(us)","I/O START(us)","I/O INTR(us)",\
    "QUEUE(us)","I/O DONE(us)") ;
}

/* I/O Start Begin */
fbt::emlxs_fca_transport:entry
{
  self->pkt_addr = arg1 ;
  ts_start_begin[self->pkt_addr] = timestamp ;
}

/* I/O Start End */
fbt::emlxs_fca_transport:return
/ self->pkt_addr /
{
  ts_start_end[self->pkt_addr] = timestamp ;
  self->pkt_addr = 0 ;
}

/* I/O Interrupt Begin */
fbt::emlxs_sli4_msi_intr:entry
{
  self->start_ts_intr = timestamp ;
}

fbt::emlxs_sli4_process_wqe_cmpl:entry
/ self->start_ts_intr /
{
  self->pkt_addr \
    = (int64_t)args[0]->fc_table[args[2]->RequestTag]->pkt ;
  ts_interrupt_begin[self->pkt_addr] = self->start_ts_intr ; 
}


/* I/O Interrupt End */
fbt::emlxs_sli4_process_wqe_cmpl:return
/ self->pkt_addr /
{
  ts_interrupt_end[self->pkt_addr] = timestamp ;
}

fbt::emlxs_sli4_process_wqe_cmpl:return
/ self->pkt_addr /
{
  self->pkt_addr = 0 ;
}

fbt::emlxs_sli4_msi_intr:return
/ self->start_ts_intr /
{
  self->start_ts_intr = 0 ;
}

/* I/O Done Begin */
fbt::emlxs_proc_channel:entry
{
  self->start_ts = timestamp ;
}

/* DEBUG I/O Done Begin */
fbt::fcp_cmd_callback:entry
/ ts_start_begin[arg0] && !ts_interrupt_begin[arg0] /
{
  printf ("kein intr\n");
  exit(0)
}

/* I/O Done End */
fbt::fcp_cmd_callback:entry
/ ts_start_begin[arg0] && ts_interrupt_begin[arg0] && self->start_ts /
{
  this->ts_done_end = timestamp ;

  this->pkt_addr = arg0 ;
  this->ts_done_begin = self->start_ts ;
  self->start_ts = 0 ;

  this->ts_start_begin = ts_start_begin[this->pkt_addr];
  ts_start_begin[this->pkt_addr] = 0 ; 
  this->ts_start_end = ts_start_end[this->pkt_addr];
  ts_start_end[this->pkt_addr] = 0 ;
  this->ts_interrupt_begin = ts_interrupt_begin[this->pkt_addr];
  ts_interrupt_begin[this->pkt_addr] = 0 ;
  this->ts_interrupt_end = ts_interrupt_end[this->pkt_addr];
  ts_interrupt_end[this->pkt_addr] = 0 ;

  this->duration_start = this->ts_start_end - this->ts_start_begin ;
  this->duration_interrupt \
    = this->ts_interrupt_end - this->ts_interrupt_begin ;
  this->duration_done = this->ts_done_end - this->ts_done_begin ;
  this->duration_total = this->ts_done_end - this->ts_start_begin ;
  this->duration_queue = this->ts_done_begin - this->ts_interrupt_end ;
  this->duration_emlxs \
    = this->duration_start + this->ts_done_end \
    - this->ts_interrupt_begin ; 
}

fbt::fcp_cmd_callback:entry
/ this->pkt_addr && this->duration_total > threshold /
{
  printf("%Y %-16d %-16d %-16d %-16d %-16d %-16d \n", \
    walltimestamp , \
    this->duration_total/1000 , this->duration_emlxs/1000 ,\
    this->duration_start/1000 , \
    this->duration_interrupt/1000 , this->duration_queue/1000 ,\
    this->duration_done/1000 
  );
}


