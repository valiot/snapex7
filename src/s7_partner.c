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
byte MyAB32[256]; // byte is a portable type of snap7.h
byte MyEB32[256]; // byte is a portable type of snap7.h
float f = 123.45;
byte* bytes = (byte*)&f;

S7Object Client;


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

    Cli_ReadArea(Client, S7AreaDB, 1, 2, 4, S7WLByte, &MyDB32);
    
    printf("0x");
    printf("%02x", MyDB32[0]);
    printf("%02x", MyDB32[1]);
    printf("%02x", MyDB32[2]);
    printf("%02x\n", MyDB32[3]);
    MyDB32[1] = 0xcb;

    result = Cli_WriteArea(Client, S7AreaDB, 1, 2, 4, S7WLByte, &MyDB32);
    printf("r = %d\n", result);

    Cli_ReadArea(Client, S7AreaDB, 1, 2, 4, S7WLByte, &MyDB32);
    printf("0x");
    printf("%02x", MyDB32[0]);
    printf("%02x", MyDB32[1]);
    printf("%02x", MyDB32[2]);
    printf("%02x\n", MyDB32[3]);
    
    MyDB32[1] = 0xca;
    result = Cli_WriteArea(Client, S7AreaDB, 1, 2, 1, S7WLWord, &MyDB32);
    printf("r = %d\n", result);

    // Read/Write Outputs test
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

    // printf("%02x", MyDB32[1]);
    // printf("%02x", MyDB32[2]);
    // printf("%02x\n", MyDB32[3]);

    Cli_Destroy(&Client);    


}