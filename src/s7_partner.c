#include "snap7.h"
#include "erlcmd.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>
#define MAX_READ 1023

int MyDB32[256]; // byte is a portable type of snap7.h
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
    printf("r = %d", result);

    Cli_DBRead(Client, 1, 2, 4, MyDB32);

    result = Cli_GetParam(Client, 10, &param);
    printf("r = %d", result);
    printf("r = %d", param);
    // printf("0x");
    // printf("%04x", MyDB32[0]);
    printf("\n");


    str = (char *) malloc(15);
    strcpy(str, array);
    printf("String = %s,  Address = %u\n", str, str);
    
    Cli_DBWrite(Client, 1, 2, 1, str);

    Cli_Destroy(&Client);    
}