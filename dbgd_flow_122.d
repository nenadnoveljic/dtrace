/*
  Version: v1.1

  Author: Nenad Noveljic

  See also: http://nenadnoveljic.com/blog/event-propagation-in-oracle-12-2

  Event propagation tracing for Oracle 12.2
*/

#pragma D option dynvarsize=64m
#pragma D option bufsize=64m
#pragma D option aggsize=64m
#pragma D option quiet

pid$target::dbgdSyncEventGrpsDirect:entry
{
  printf("-----------\n");
  this->first_ptr_val = *(uint64_t *)copyin(arg1+16,16) ; 
  this->second_ptr_adr = this->first_ptr_val + 184 ;
  this->second_ptr_val = *(uint64_t *)copyin(this->second_ptr_adr,16) ;
  printf("%s  arg1      = %x \n1st ptr *(arg1+0x10):    *%x = %x\n2nd ptr *(1st_ptr+0xb8): *%x = %x  \n",
    probefunc, arg1, arg1+16, this->first_ptr_val,
    this->second_ptr_adr, this->second_ptr_val
  );
}

pid$target::dbgdLinkEvent:entry
{
  printf("-----------\n");
  printf("%s entry arg2:%x arg3:%x\n",probefunc,arg2,arg3);
}

pid$target::dbgdSetEvents:entry
{
  printf("-----------\n");
  self->SetEvents_arg2 = arg2 ;
  self->SetEvents_arg2_0xa8 = arg2 + 0xa8 ;
  printf("%s entry\narg2=%x \n",
    probefunc,arg2
  );
}

pid$target::dbgdSetEvents:return
{
  printf("-----------\n");
  printf("%s return \n*arg2: *(%x) = %x \n",
    probefunc,self->SetEvents_arg2,
    *(uint64_t *)copyin(self->SetEvents_arg2,8)
  );
}

pid$target::dbgdCopyEventNode:entry
{
  printf("-----------\n");
  printf("dbgdCopyEventNode source: arg2 = %x \n*(arg2+0x28): *(%x) = %x\n",
    arg2,arg2+40,
    *(int *)copyin(arg2+40,1)
  );
}

pid$target::dbgdCopyEventNode:return
{
  this->ret_value = *(uint64_t *)copyin(arg1,8) ;
  this->ptr_mask = this->ret_value + 40 ;
  printf("dbgdCopyEventNode destination: *ret_val = %x \n*ptr_mask = *ret_val+0x28: *(%x) = %x\n",
    this->ret_value, this->ptr_mask, 
    *(int *)copyin(this->ptr_mask,1)
  );
}


