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
ei_x_buff x;

S7Object Client;

int main()
{
    struct erlcmd handler;
    Client = Cli_Create();

    Cli_ConnectTo(Client,"192.168.10.100",0,2);

    Cli_DBRead(Client, 32, 0, 16, &MyDB32);

    Cli_Destroy(&Client);
    printf("Ejecute\n");   
    erlcmd_process(&handler);
}
