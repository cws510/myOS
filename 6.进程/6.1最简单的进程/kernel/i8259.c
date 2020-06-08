#include"proto.h"
#include"const.h"
#include"protect.h"
#include"type.h"

//-------------------------------------------------------------------------
//		init_8259A 初始化8259A
//-------------------------------------------------------------------------
PUBLIC void init_8259A()
{
	//主8259A,ICW1
	out_byte(INT_M_CTL, 0x11);
	//从8259A,ICW1
	out_byte(INT_S_CTL, 0x11);

	//主8259A,ICW2,设置主8259A中断入口地址为0x20
	out_byte(INT_M_CTLMASK, INT_VECTOR_IRQ0);
	//从8259A,ICW2,设置从8259A中断入口地址为0x28
	out_byte(INT_S_CTLMASK, INT_VECTOR_IRQ8);

	//主8259A,ICW3,IR2对应从8259A
	out_byte(INT_M_CTLMASK, 0x04);
	//从8259A,ICW3,对应主8259A的IR2
	out_byte(INT_S_CTLMASK, 0x02);

	//主8259A,ICW4
	out_byte(INT_M_CTLMASK, 0x01);
	//从8259A,ICW4
	out_byte(INT_S_CTLMASK, 0x01);

	//主8259A,OCW1
	out_byte(INT_M_CTLMASK, 0xFE);	//FE打开时钟中断
	//从8259A,OCW1
	out_byte(INT_S_CTLMASK, 0xFF);
	
}


//-------------------------------------------------------------------------
//		spurious_irq 初中断处理函数
//-------------------------------------------------------------------------
PUBLIC void spurious_irq(int irq)
{
	char *s = "spurious_irq:";
	disp_str(s);
	disp_int(irq);
	//disp_str("\n");
}
