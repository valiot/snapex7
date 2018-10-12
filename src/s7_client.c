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
        ei_encode_atom(resp, &resp_index, err_s7[index_iso-1]);
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
    if (result != 0)
        //the paramater was invalid.
        send_snap7_errors(result);
            
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
    if (result != 0)
        send_snap7_errors(result);
            
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
    if (result != 0)
        //the paramater was invalid.
        send_snap7_errors(result);
            
    send_ok_response();
}

/**
 * Connects the client to the PLC with the parameters specified in the previous call of
 * Cli_ConnectTo() or Cli_SetConnectionParams(), usually used after Cli_Disconnect().
*/
static void handle_connect(const char *req, int *req_index)
{   
    
    int result = Cli_Connect(Client);
    if (result != 0)
        send_snap7_errors(result);
            
    send_ok_response();
}
/**
 *  Disconnects “gracefully” the Client from the PLC. 
*/
static void handle_disconnect(const char *req, int *req_index)
{   
    
    int result = Cli_Disconnect(Client);
    if (result != 0)
        send_snap7_errors(result);
            
    send_ok_response();
}



static void handle_test(const char *req, int *req_index)
{
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