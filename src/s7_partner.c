#include "snap7.h"
#include "erlcmd.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#define MAX_READ 1023

byte MyDB32[256]; // byte is a portable type of snap7.h
byte DB1[20]; // byte is a portable type of snap7.h
byte DB2[20]; // byte is a portable type of snap7.h
byte MyAB32[256]; // byte is a portable type of snap7.h
byte MyEB32[256]; // byte is a portable type of snap7.h
int MyTM32[256]; // byte is a portable type of snap7.h
float f = 123.45;
byte* bytes = (byte*)&f;
S7Object Server;
S7Object Client;

void ReadmultiVars(void *array)
{
    byte *DB = ((TS7DataItem *)array)[0].pdata; 
    printf("r = %d\n", ((TS7DataItem *)array)[0].Result);
    printf("0x");
    //printf("%02x", );
    printf("%02x", DB[0]);
    printf("%02x", DB[1]);
    printf("%02x", DB[2]);
    printf("%02x", DB[3]);
    printf("\n");
    //byte *DB = ((TS7DataItem *)array)[0].pdata; 
    printf("0x");
    printf("%02x", ((byte *)((TS7DataItem *)array)[1].pdata)[0]);
    printf("\n");
}

void print_arrays(byte *data,int size)
{
    for(int i = 0; i < size; i++)
    {
        printf("%02x ", data[i]);
    }
    printf("\n");
}

int main()
{
    char *str;
    char *str1 = "tutorialspoint";
    char array[] = {'H','o','l','a'};
    struct erlcmd handler;
    Client = Cli_Create();
    uint32_t param;
    int result = Cli_ConnectTo(Client,"192.168.0.1",0,1);
    printf("r = %d\n", result);

    // Read/Write Area test
    printf("Read/write area test-----------------------------\n");
    Cli_ReadArea(Client, S7AreaDB, 1, 2, 4, S7WLByte, &MyDB32);
    
    printf("0x");
    printf("%02x", MyDB32[0]);
    printf("%02x", MyDB32[1]);
    printf("%02x", MyDB32[2]);
    printf("%02x\n", MyDB32[3]);
    MyDB32[1] = 0xcb;
    MyDB32[3] = 0x00;

    result = Cli_WriteArea(Client, S7AreaDB, 1, 2, 4, S7WLByte, &MyDB32);
    printf("r = %d\n", result);

    MyDB32[0] = 0x00;
    MyDB32[1] = 0x00;
    MyDB32[2] = 0x00;
    MyDB32[3] = 0x00;
    Cli_ReadArea(Client, S7AreaDB, 1, 2, 4, S7WLByte, &MyDB32);
    printf("0x");
    printf("%02x", MyDB32[0]);
    printf("%02x", MyDB32[1]);
    printf("%02x", MyDB32[2]);
    printf("%02x\n", MyDB32[3]);
    
    MyDB32[1] = 0xca;
    result = Cli_WriteArea(Client, S7AreaDB, 1, 2, 1, S7WLWord, &MyDB32);
    printf("r = %d\n", result);

    printf("Read/writeVars test-----------------------------\n");

    printf("S7WLWord test-----------------------------\n");
    Cli_ReadArea(Client, S7AreaDB, 1, 2, 2, S7WLWord, &MyDB32);
    printf("0x");
    printf("%02x", MyDB32[0]);
    printf("%02x", MyDB32[1]);
    printf("%02x", MyDB32[2]);
    printf("%02x\n", MyDB32[3]);

    printf("Read/writeVars test-----------------------------\n");
    Cli_ABRead(Client, 0, 1, &MyAB32);
    printf("0x");
    printf("%02x", MyAB32[0]);
    printf("\n");

    MyAB32[0] = 0x01;
    result = Cli_ABWrite(Client, 0, 1, &MyAB32);
    printf("r = %d\n", result);

    Cli_ABRead(Client, 0, 1, &MyAB32);
    printf("0x");
    printf("%02x", MyAB32[0]);
    printf("\n");
    sleep(1);
    MyAB32[0] = 0x00;
    result = Cli_ABWrite(Client, 0, 1, &MyAB32);
    printf("r = %d\n", result);

    Cli_ABRead(Client, 0, 1, &MyAB32);
    printf("0x");
    printf("%02x", MyAB32[0]);
    printf("\n");

    // Read/Write Input test
    Cli_EBRead(Client, 0, 1, &MyEB32);
    printf("0x");
    printf("%02x", MyEB32[0]);
    printf("\n");

    printf("TM_Read test-----------------------------\n");
    result = Cli_TMRead(Client, 0, 1, &MyTM32);
    printf("r = %d\n", result);
    printf("%02x", MyTM32[0]);
    printf("%02x", MyTM32[1]);
    printf("\n");

    printf("CT_Read test-----------------------------\n");
    result = Cli_CTRead(Client, 0, 1, &MyTM32);
    printf("r = %d\n", result);
    printf("%02x", MyTM32[0]);
    printf("%02x", MyTM32[1]);
    printf("\n");

    //ReadmultiVars Test
    printf("ReadMultiVars test-----------------------------\n");
    TS7DataItem Items[2];

    Items[0].Area = S7AreaDB;
    Items[0].WordLen = S7WLByte;
    Items[0].DBNumber = 1;
    Items[0].Start= 2;
    Items[0].Amount= 4;
    Items[0].pdata = &DB1;

    Items[1].Area = S7AreaPE;
    Items[1].WordLen = S7WLByte;
    Items[1].DBNumber = 0;
    Items[1].Start= 0;
    Items[1].Amount= 1;
    Items[1].pdata = &DB2;

    result = Cli_ReadMultiVars(Client, &Items[0], 2);
    ReadmultiVars(&Items);

    printf("readszl test-----------------------------\n");
    int ID = 0x0111;
    int Index = 0x0006;
    TS7SZL data;
    int size = sizeof(data);
    result = Cli_ReadSZL(Client, ID, Index, &data, &size);
    printf("r = %d\n", result);
    printf("size = %d\n", size);
    printf("LENTHDR = %d\n", data.Header.LENTHDR);
    printf("N_DR = %d\n", data.Header.N_DR);
    int lim =  data.Header.LENTHDR*data.Header.N_DR;
    for(int index =0; index<size; index++) 
    {
        printf("b%d = %d\n", index, data.Data[index]);
    }

    
    printf("readszl_list test-----------------------------\n");
    TS7SZLList data2;
    size = sizeof(data2);
    printf("size = %d\n", size);
    result = Cli_ReadSZLList(Client, &data2, &size);
    printf("r = %d\n", result);
    printf("size = %d\n", size);
    printf("LENTHDR = %d\n", data2.Header.LENTHDR);
    printf("N_DR = %d\n", data2.Header.N_DR);
    lim =  data2.Header.LENTHDR*data2.Header.N_DR;
    for(int index =0; index<size; index++) 
    {
        printf("b%d = %d\n", index, data2.List[index]);
    }
    
    printf("GetOrder code-----------------------------\n");
    TS7OrderCode data3;
    result = Cli_GetOrderCode(Client, &data3);
    printf("r = %d\n", result);
    for(int index =0; index<21; index++) 
    {
        printf("b%d = %d\n", index, data3.Code[index]);
    }
    printf("V1 = %d\n", data3.V1);
    printf("V2 = %d\n", data3.V2);
    printf("V3 = %d\n", data3.V3);    

    // //GetCpuInfo S7-1200 not supported
    // TS7CpuInfo Info;
    // result = Cli_GetCpuInfo(Client, &Info);
    // printf("r = %d\n", result);
    // printf("%s\n", Info.ModuleTypeName);
    // printf("%s\n", Info.SerialNumber);
    // printf("%s\n", Info.ASName);
    // printf("%s\n", Info.ModuleName);

    // //GetCpInfo S7-1200 not supported
    // TS7CpInfo info;
    // result = Cli_GetCpInfo(Client, &info);
    // printf("r = %d\n", result);
    // printf("%d\n", info.MaxPduLengt);
    // printf("%d\n", info.MaxConnections);
    // printf("%d\n", info.MaxMpiRate);
    // printf("%d\n", info.MaxBusRate);

    // //GetProtection S7-1200 not supported
    // TS7Protection data4;
    // result = Cli_GetProtection(Client, &data4);
    // printf("r = %d\n", result);
    // printf("V1 = %d\n", data4.anl_sch);
    // printf("V2 = %d\n", data4.bart_sch);
    // printf("V3 = %d\n", data4.sch_par);
    // printf("V4 = %d\n", data4.sch_rel);
    // printf("V5 = %d\n", data4.sch_schal);

    printf("GetPlcStatus test-----------------------------\n");
    int status;
    result = Cli_GetPlcStatus(Client, &status);
    switch(status)
    {
        case 0x00:
            printf("S7CpuStatusUnknown\n");
        break;
        
        case 0x04:
            printf("S7CpuStatusStop\n");
        break;

        case 0x08:
            printf("S7CpuStatusRun\n");
        break;

        default:
            errx(EXIT_FAILURE, ":get_plc_status unknown snap7 status = %d\n", status);
        break;
    }

    printf("PLCStop test-----------------------------\n");
    result = Cli_PlcStop(Client);
    printf("r = %d\n", result);
    
    printf("Server test-----------------------------\n");
    Server = Srv_Create();
    u_int16_t res = 4040;
    int Error = Srv_SetParam(Server, 1, &res);
    printf("r = %d\n", Error);
    Error = Srv_GetParam(Server, 1, &res);
    printf("r = %d\n", Error);
    printf("res = %d\n", res);
    
    Error=Srv_Start(Server);
    printf("r = %d\n", Error);
    Srv_Destroy(&Server);

    printf("Cli_GetExecTime test-----------------------------\n");
    int time;
    result = Cli_GetExecTime(Client, &time);
    printf("r = %d\n", result);
    printf("res = %d\n", time);

    printf("Cli_GetLastError test-----------------------------\n");
    int error;
    result = Cli_GetLastError(Client, &error);
    printf("r = %d\n", result);
    printf("res = %d\n", error);
    
    printf("Cli_GetPduLength test-----------------------------\n");
    int req_neg[2];
    result = Cli_GetPduLength(Client, &req_neg[0], &req_neg[1]);
    printf("r = %d\n", result);
    printf("req = %d\n", req_neg[0]);
    printf("neg = %d\n", req_neg[1]);

    printf("Cli_ErrorTest test-----------------------------\n");
    char text[50];
    result = Cli_ErrorText(111, text, 50);
    printf("r = %d\n", result);
    printf("%s", text);
    printf("\n");

    printf("Connected test-----------------------------\n");
    int response;
    result = Cli_GetConnected(Client, &response);
    printf("r = %d\n", result);
    printf("res = %d\n", response);

    printf("ISO PDU test-----------------------------\n");
    //db read
    byte pdu[] = {0x32, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x04, 0x01, 0x12, 0x0a, 0x10, 0x02, 0x00, 0x04, 0x00, 0x01, 0x84, 0x00, 0x00, 0x10};
    int siz = sizeof(pdu);
    printf("siz before=%d\n", siz);
    result = Cli_IsoExchangeBuffer(Client, &pdu, &siz);
    result = Cli_ErrorText(result, text, 50);
    printf("%s\n", text);
    printf("siz after=%d\n", siz);
    print_arrays(pdu, siz);

    Cli_Destroy(&Client);    
}