#pragma D option quiet

pid$target:oracle:kslgetl:entry,
pid$target:oracle:kslfre:entry
/ arg0 >= $1 && arg0 <= $2 /
{
  printf("\n\n%s: 0x%X %d 0x%X %d\n", probefunc, arg0, arg1, arg2, arg3);
  ustack();
}

pid$target:oracle:kslgetl:entry
/ arg0 >= $1 && arg0 <= $2 /
{
  self->ts = timestamp ;
  self->ts_cpu = vtimestamp ;
}

pid$target:oracle:kslfre:entry
/ arg0 >= $1 && arg0 <= $2 && self->ts /
{
  this->elapsed = timestamp - self->ts ;
  this->cpu = vtimestamp - self->ts_cpu ;
  printf("elapsed: %d, cpu: %d\n", this->elapsed, this->cpu);
  self->ts = 0 ;
  self->ts_cpu = 0 ;
}
