#include"proto.h"
#include"protect.h"
#include"string.h"
#include"global.h"

void TestA();

void restart();

PUBLIC int kernel_main()
{
	disp_str("------kernel_main begins-------\n");

	//初始化变量(解决中断重入问题) 
	k_reenter = -1;	

	//初始化进程表
	PROCESS *p_proc = proc_table;
	
	p_proc->ldt_sel = SELECTOR_LDT_FIRST;    //SELECTOR_LDT_FIRST=0x28
	//SELECTOR_KERNEL_CS=0x08 0x08>>3=0x01
	memcpy(&p_proc->ldts[0],&gdt[SELECTOR_KERNEL_CS>>3],sizeof(DESCRIPTOR));
	p_proc->ldts[0].attr1 = DA_C | PRIVILEGE_TASK << 5;   //改变DPL
	memcpy(&p_proc->ldts[1],&gdt[SELECTOR_KERNEL_DS>>3],sizeof(DESCRIPTOR));
	p_proc->ldts[1].attr1 = DA_DRW | PRIVILEGE_TASK << 5; //改变DPL

	p_proc->regs.cs = (0 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.ds = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.es = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.fs = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.ss = (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | RPL_TASK;
	p_proc->regs.gs = (SELECTOR_KERNEL_GS & SA_RPL_MASK) | RPL_TASK;

	p_proc->regs.eip = (u32)TestA;
	p_proc->regs.esp = (u32)task_stack + STACK_SIZE_TOTAL;	//STACK_SIZE_TOTAL=0x8000
								//task_stack[]是一个数组
								//使esp指向进程的堆栈段
	p_proc->regs.eflags = 0x1202;

	//disp_str("------kernel_main ends-------\n");
	p_proc_ready = proc_table;
	restart();
		
	
	while(1){}
}



void TestA()
{
	int i = 0;
	while(1){
		disp_str("A");
		disp_int(i++);
		disp_str(".");
		delay(1);
	}
}
