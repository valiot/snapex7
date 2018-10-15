#include "snap7.h"
#include "erlcmd.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>

S7Object Client;

// Utilities for communication and error handling
static const char response_id = 'r';
static const char notification_id = 'n';
const char err_s7[0x26][37] = { 
    "errNegotiatingPDU",
    "errCliInvalidParams", 
    "errCliJobPending",
    "errCliTooManyItems",
    "errCliInvalidWordLen",
    "errCliPartialDataWritten",
    "errCliSizeOverPDU",
    "errCliInvalidPlcAnswer",
    "errCliAddressOutOfRange",
    "errCliInvalidTransportSize",
    "errCliWriteDataSizeMismatch",
    "errCliItemNotAvailable",
    "errCliInvalidValue",
    "errCliCannotStartPLC",
    "errCliAlreadyRun",
    "errCliCannotStopPLC",
    "errCliCannotCopyRamToRom",
    "errCliCannotCompress",
    "errCliAlreadyStop",
    "errCliFunNotAvailable",
    "errCliUploadSequenceFailed",
    "errCliInvalidDataSizeRecvd",
    "errCliInvalidBlockType",
    "errCliInvalidBlockNumber",
    "errCliInvalidBlockSize",
    "errCliDownloadSequenceFailed",
    "errCliInsertRefused",
    "errCliDeleteRefused",
    "errCliNeedPassword",
    "errCliInvalidPassword",
    "errCliNoPasswordToSetOrClear",
    "errCliJobTimeout",
    "errCliPartialDataRead",
    "errCliBufferTooSmall",
    "errCliFunctionRefused",
    "errCliInvalidParamNumber",
    "errCliDestroying",
    "errCliCannotChangeParam"
    };

const char err_iso[0x0F][37] = {
    "errIsoConnect",
    "errIsoDisconnect",
    "errIsoInvalidPDU",
    "errIsoInvalidDataSize",
    "errIsoNullPointer",
    "errIsoShortPacket",
    "errIsoTooManyFragments",
    "errIsoPduOverflow",
    "errIsoSendPacket",
    "errIsoRecvPacket",
    "errIsoInvalidParams",
    "errIsoResvd_1",
    "errIsoResvd_2",
    "errIsoResvd_3",
    "errIsoResvd_4"
};

struct client_config
{
    bool active;
    char *ip_adress;      //string as "192.168.1.2"
    int rack;             // 5, 6, 7, 8
    int socket;           // 1 or 2
};

/**
 * @brief Send :ok back to Elixir
 */
static void send_ok_response()
{
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_atom(resp, &resp_index, "ok");
    erlcmd_send(resp, resp_index);
}

/**
 * @brief Send data back to Elixir in form of {:ok, data}
 */
static void send_data_response(void *data, int data_type, int data_len)
{
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_tuple_header(resp, &resp_index, 2);
    ei_encode_atom(resp, &resp_index, "ok");
    
    switch(data_type)
    {
        case 1: //signed (long)
            ei_encode_long(resp, &resp_index,*(int32_t *)data);
        break;

        case 2: //unsigned (long)
            ei_encode_ulong(resp, &resp_index,*(uint32_t *)data);
        break;

        case 3: //strings
            ei_encode_string(resp, &resp_index, data);
        break;

        case 4: //doubles
            ei_encode_double(resp, &resp_index, *(double *)data );
        break;

        case 5: //arrays (char type)
            ei_encode_binary(resp, &resp_index, data, data_len);
        break;

        default:
            errx(EXIT_FAILURE, "data_type error");
        break;
    }

    erlcmd_send(resp, resp_index);
}

/**
 * @brief Send a response of the form {:error, reason}
 *
 * @param reason a reason (sent back as an atom)
 */
static void send_error_response(const char *reason)
{
    char resp[256];
    int resp_index = sizeof(uint16_t); // Space for payload size
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_tuple_header(resp, &resp_index, 2);
    ei_encode_atom(resp, &resp_index, "error");
    ei_encode_atom(resp, &resp_index, reason);
    erlcmd_send(resp, resp_index);
}

/**
 * @brief Send a response of the form {:error, reasons}
 *  where 'reasons' is map (%{es7: atom/nil, eiso: atom/nil, etcp: int/nil}), 
 *  (check documentation 'snap7/doc/snap7-refman.pdf' for more details,
 *  pg. 253) or nil if no error related to that key.
 * @param code, is an error code from snap7 source code.
 */
static void send_snap7_errors(uint32_t code)
{
    char resp[256];
    int index_s7 = code / 0x100000;
    int index_iso = (code & 0x000F0000)/ 0x10000;
    int index_tcp = (code & 0xFFFF);
    int resp_index = sizeof(uint16_t); // Space for payload size
    
    resp[resp_index++] = response_id;
    ei_encode_version(resp, &resp_index);
    ei_encode_tuple_header(resp, &resp_index, 2);
    ei_encode_atom(resp, &resp_index, "error");
    ei_encode_map_header(resp, &resp_index, 3);
    
    ei_encode_atom(resp, &resp_index, "es7");
    if(index_s7 != 0)
        ei_encode_atom(resp, &resp_index, err_s7[index_s7-1]);
    else
        ei_encode_atom(resp, &resp_index, "nil");
    
    ei_encode_atom(resp, &resp_index, "eiso");
    if(index_iso != 0)
        ei_encode_atom(resp, &resp_index, err_iso[index_iso-1]);
    else
        ei_encode_atom(resp, &resp_index, "nil");

    ei_encode_atom(resp, &resp_index, "etcp");
    if(index_tcp != 0)
        ei_encode_char(resp, &resp_index, index_tcp);
    else
        ei_encode_atom(resp, &resp_index, "nil");


    erlcmd_send(resp, resp_index);
}

static void debug_str(const char *msg)
{
    send_error_response(msg);
}

static void debug_vars(unsigned long var)
{
    char msg[10];
    sprintf(msg, "val=%d", (int)var);
    send_error_response(msg);
}

/* 
    Snap7 Handlers
*/

//    Administrative functions

/*
    Sets the connection resource type, i.e the way in which the Clients
    connects to a PLC.
    :param connection_type(int): 1 for PG, 2 for OP, 3 to 10 for S7 Basic
*/
static void handle_set_connection_type(const char *req, int *req_index)
{
    char val;
    if (ei_decode_char(req, req_index, &val) < 0) {
        send_error_response("einval");
        return;
    }

    int result = Cli_SetConnectionType(Client, val);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/*
    Connect to a S7 server.
    :param address: IP address of server
    :param rack: rack on server
    :param slot: slot on server.
*/
static void handle_connect_to(const char *req, int *req_index)
{   
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":open requires a 3-tuple, term_size = %d", term_size);

    char ip[20];
    long binary_len;
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
            term_type != ERL_BINARY_EXT ||
            term_size >= (int) sizeof(ip) ||
            ei_decode_binary(req, req_index, ip, &binary_len) < 0) {
        // The name is almost certainly too long, so report that it
        // doesn't exist.
        send_error_response("enoent");
        return;
    }
    ip[term_size] = '\0';

    unsigned long rack;
    if (ei_decode_ulong(req, req_index, &rack) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long slot;
    if (ei_decode_ulong(req, req_index, &slot) < 0) {
        send_error_response("einval");
        return;
    }
    
    int result = Cli_ConnectTo(Client, ip, (int)rack, (int)slot);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/*
    Sets internally (IP, LocalTSAP, RemoteTSAP) Coordinates.
    this function must be called just before Cli_Connect().
    :param address: PLC/Equipment IPV4 Address, for example "192.168.1.12"
    :param local_tsap: Local TSAP (PC TSAP)
    :param remote_tsap: Remote TSAP (PLC TSAP)
*/
static void handle_set_connection_params(const char *req, int *req_index)
{   
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":open requires a 3-tuple, term_size = %d", term_size);

    char ip[20];
    long binary_len;
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
            term_type != ERL_BINARY_EXT ||
            term_size >= (int) sizeof(ip) ||
            ei_decode_binary(req, req_index, ip, &binary_len) < 0) {
        // The name is almost certainly too long, so report that it
        // doesn't exist.
        send_error_response("enoent");
        return;
    }
    ip[term_size] = '\0';

    unsigned long local_tsap;
    if (ei_decode_ulong(req, req_index, &local_tsap) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long remote_tsap;
    if (ei_decode_ulong(req, req_index, &remote_tsap) < 0) {
        send_error_response("einval");
        return;
    }

    int result = Cli_SetConnectionParams(Client, ip, (uint16_t)local_tsap, (uint16_t)remote_tsap);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 * Connects the client to the PLC with the parameters specified in the previous call of
 * Cli_ConnectTo() or Cli_SetConnectionParams(), usually used after Cli_Disconnect().
*/
static void handle_connect(const char *req, int *req_index)
{   
    
    int result = Cli_Connect(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}
/**
 *  Disconnects “gracefully” the Client from the PLC. 
*/
static void handle_disconnect(const char *req, int *req_index)
{   
    
    int result = Cli_Disconnect(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  Reads an internal Client object parameter. (details in pg.)
*/
static void handle_get_params(const char *req, int *req_index)
{   
    
    char ind_param;
    int result;

    if (ei_decode_char(req, req_index, &ind_param) < 0) {
        send_error_response("einval");
        return;
    }

    uint32_t data;
    switch (ind_param)
    {
        case 2: //
        case 7: // u16
        case 8: // 
        case 9: 
            result = Cli_GetParam(Client, ind_param, &data);
            if (result != 0){
                //the paramater was invalid.
                send_snap7_errors(result);
                return;
            }
            send_data_response(&data, 2, 0);
        break;
        
        case 3: //
        case 4: // s16
        case 5: //
        case 10:
            result = Cli_GetParam(Client, ind_param, &data);
            if (result != 0){
                //the paramater was invalid.
                send_snap7_errors(result);
                return;
            }
            send_data_response(&data, 1, 0);
        break;

        default:
            send_error_response("einval");
        break;
    }
}

/**
 *  Reads an internal Client object parameter. (details in pg.)
*/
static void handle_set_params(const char *req, int *req_index)
{   
    int result;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":open requires a 2-tuple, term_size = %d", term_size);

    char ind_param;
    if (ei_decode_char(req, req_index, &ind_param) < 0) {
        send_error_response("einval");
        return;
    }

    int64_t data;
    if (ei_decode_long(req, req_index, &data) < 0) {
        send_error_response("einval");
        return;
    }
    
    switch (ind_param)
    {
        case 2: 
        case 7: 
        case 8: 
        case 9:        
        case 3: 
        case 4: 
        case 5: 
        case 10:
            result = Cli_SetParam(Client, ind_param, &data);
            if (result != 0){
                //the paramater was invalid.
                send_snap7_errors(result);
                return;
            }
            send_ok_response();
        break;

        default:
            send_error_response("einval");
        break;
    }
}

//    Data I/O functions

/**
 *  This is the main funcion to read from a PLC.
 *  With it you can read DB, Inputs, Outputs, Merkers, Timers and Counters
 *  (check pg. 104 for details).
*/
static void handle_read_area(const char *req, int *req_index)
{   
    char data_len;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 5)
        errx(EXIT_FAILURE, ":open requires a 5-tuple, term_size = %d", term_size);

    unsigned long area;
    if (ei_decode_ulong(req, req_index, &area) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long db_number;
    if (ei_decode_ulong(req, req_index, &db_number) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long amount;
    if (ei_decode_ulong(req, req_index, &amount) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long data_type; //wordLen
    if (ei_decode_ulong(req, req_index, &data_type) < 0) {
        send_error_response("einval");
        return;
    }

    switch(data_type)
    {
        case 0x01:
        case 0x02:  
            data_len = 1;
        break;

        case 0x04: 
        case 0x1C:
        case 0x1D:  
            data_len = 2;
        break;
        
        case 0x06: 
        case 0x08: 
            data_len = 4;
        break;
    }
    
    unsigned char data[data_len*amount];
    int result = Cli_ReadArea(Client, (int)area, (int)db_number, (int)start, (int)amount, (int)data_type, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}
/**
 *  This is the main functiion to write data into a PLC. It's the 
 *  complementary function of 'read_area', the parameters and their
 *  meanings are the same. The only difference is that the data is
 *  transferred from the buffer pointed by data into the PLC.
*/
static void handle_write_area(const char *req, int *req_index)
{   
    char data_len;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 6)
        errx(EXIT_FAILURE, ":open requires a 6-tuple, term_size = %d", term_size);

    unsigned long area;
    if (ei_decode_ulong(req, req_index, &area) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long db_number;
    if (ei_decode_ulong(req, req_index, &db_number) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long amount;
    if (ei_decode_ulong(req, req_index, &amount) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long data_type; //wordLen
    if (ei_decode_ulong(req, req_index, &data_type) < 0) {
        send_error_response("einval");
        return;
    }

    switch(data_type)
    {
        case 0x01:
        case 0x02:  
            data_len = 1;
        break;

        case 0x04: 
        case 0x1C:
        case 0x1D:  
            data_len = 2;
        break;
        
        case 0x06: 
        case 0x08: 
            data_len = 4;
        break;

        default:
            errx(EXIT_FAILURE, "inconsistent data_type = %ld", data_type);
        break;
    }
    
    unsigned char data[data_len*amount];

    if(ei_decode_binary(req, req_index, data, &term_size) < 0 ||
        term_size != (data_len*amount))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %d", (data_len*amount), term_size);
    
    int result = Cli_WriteArea(Client, (int)area, (int)db_number, (int)start, (int)amount, (int)data_type, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}


static void handle_test(const char *req, int *req_index)
{
    // char x[12] = {0x01,0x02,0x03,0x00, 0xff,0x01,0x01,0x02,0x03,0x00, 0xff,0x01};
    // send_data_response(x, 5, sizeof(x));
    // char resp[256];
    // int16_t binary[]={0x1010, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F};
    // int resp_index = sizeof(uint16_t); // Space for payload size
    // resp[resp_index++] = response_id;
    // ei_encode_version(resp, &resp_index);
    // ei_encode_binary(resp, &resp_index, binary, 18);
    // erlcmd_send(resp, resp_index);
    send_ok_response();
}

/* Elixir request handler table
 * Ordered roughly based on most frequent calls to least.
 */
struct request_handler {
    const char *name;
    void (*handler)(const char *req, int *req_index);
};

static struct request_handler request_handlers[] = {
    { "test", handle_test},
    {"set_connection_type", handle_set_connection_type},
    {"connect_to", handle_connect_to},
    {"set_connection_params", handle_set_connection_params},
    {"connect", handle_connect},
    {"disconnect", handle_disconnect},
    {"get_params", handle_get_params},
    {"set_params", handle_set_params},
    {"read_area", handle_read_area},
    {"write_area", handle_write_area},
    { NULL, NULL }
};

/**
 * @brief Decode and forward requests from Elixir to the appropriate handlers
 * @param req the undecoded request
 * @param cookie
 */
static void handle_elixir_request(const char *req, void *cookie)
{
    (void) cookie;

    // Commands are of the form {Command, Arguments}:
    // { atom(), term() }
    int req_index = sizeof(uint16_t);
    if (ei_decode_version(req, &req_index, NULL) < 0)
        errx(EXIT_FAILURE, "Message version issue?");

    int arity;
    if (ei_decode_tuple_header(req, &req_index, &arity) < 0 ||
            arity != 2)
        errx(EXIT_FAILURE, "expecting {cmd, args} tuple");

    char cmd[MAXATOMLEN];
    if (ei_decode_atom(req, &req_index, cmd) < 0)
        errx(EXIT_FAILURE, "expecting command atom");
    
    //execute all handler
    for (struct request_handler *rh = request_handlers; rh->name != NULL; rh++) {
        if (strcmp(cmd, rh->name) == 0) {
            rh->handler(req, &req_index);
            return;
        }
    }
    // no listed function
    errx(EXIT_FAILURE, "unknown command: %s", cmd);
}

int main()
{
    Client = Cli_Create();

    struct erlcmd *handler = malloc(sizeof(struct erlcmd));
    erlcmd_init(handler, handle_elixir_request, NULL);

    for (;;) {
        struct pollfd fdset;

        fdset.fd = STDIN_FILENO;
        fdset.events = POLLIN;
        fdset.revents = 0;

        int timeout = -1; // Wait forever unless told by otherwise
        int rc = poll(&fdset, 1, timeout);

        if (rc < 0) {
            // Retry if EINTR
            if (errno == EINTR)
                continue;

            err(EXIT_FAILURE, "poll");
        }

        if (fdset.revents & (POLLIN | POLLHUP)) {
            if (erlcmd_process(handler))
                break;
        }
    }
    // Kill client
    Cli_Destroy(&Client);    
}