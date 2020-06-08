#include"type.h"
#include"protect.h"
#include"const.h"
#include"string.h"
#include"proto.h"
#include"global.h"


//----------------------------------------------------------------------------------
//					cstart
//----------------------------------------------------------------------------------
PUBLIC void cstart()
{
	disp_pos = 0;
	//打印字符串
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n-----cstart begin------\n");

	//初始化message_1字符串
	message_1 = "^";	
	
	
	//将loader中的GDT复制到新的GDT中
	memcpy((u32*)gdt,(void*)(*((u32*)(&gdt_ptr[2]))),*((u16*)(&gdt_ptr[0]))+1); //参数1:新的GDT的基地址 参数2:段基址 参数3:段界限
	// gdt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。用作 sgdt/lgdt 的参数。
	u16* gdt_limit = (u16*)(&gdt_ptr[0]);
	u32* gdt_base = (u32*)(&gdt_ptr[2]);
	*gdt_limit = GDT_SIZE*sizeof(DESCRIPTOR) - 1;
	*gdt_base = (u32)gdt;	

	// idt_ptr[6] 共 6 个字节：0~15:Limit  16~47:Base。用作 sidt/lidt 的参数。
	u16* idt_limit = (u16*)(&idt_ptr[0]);
	u32* idt_base = (u32*)(&idt_ptr[2]);
	*idt_limit = IDT_SIZE*sizeof(GATE) - 1;
	*idt_base = (u32)idt;

	//初始化中断描述符
	init_proc();

	//打印字符串
	disp_str("-----cstart   end------\n");
}
