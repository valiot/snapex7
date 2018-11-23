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
    char version[5];
    uint32_t code;
    byte r_len = 1;
    long i_struct;
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

        case 5: //arrays (byte type)
            ei_encode_binary(resp, &resp_index, data, data_len);
        break;

        case 6: //atom
            ei_encode_atom(resp, &resp_index, data);
        break;

        case 7: //TS7DataItem
            ei_encode_list_header(resp, &resp_index, data_len);
            for(i_struct = 0; i_struct < data_len; i_struct++) 
            {
                byte *batch_data = ((TS7DataItem *)data)[i_struct].pdata; 
                int amount = ((TS7DataItem *)data)[i_struct].Amount;
                int w_len = ((TS7DataItem *)data)[i_struct].WordLen;
                switch(w_len)
                {
                    case 0x01:
                    case 0x02:  
                        r_len = 1;
                    break;

                    case 0x04: 
                    case 0x1C:
                    case 0x1D:  
                        r_len = 2;
                    break;
                    
                    case 0x06: 
                    case 0x08: 
                        r_len = 4;
                    break;
                }
                ei_encode_binary(resp, &resp_index, batch_data, amount*r_len);
            }
            ei_encode_empty_list(resp, &resp_index);        
        break;

        case 8: // array ulongs
            ei_encode_list_header(resp, &resp_index, data_len);
            for(i_struct = 0; i_struct < data_len; i_struct++) 
            {
               ei_encode_ulong(resp, &resp_index, *(uint16_t *)data);
               data+=2;
            }
            ei_encode_empty_list(resp, &resp_index);        
        break;

        case 9: // TS7BlocksList
            ei_encode_list_header(resp, &resp_index, data_len);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "OBCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->OBCount);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "FBCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->FBCount);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "FCCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->FCCount);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "SFBCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->SFBCount);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "SFCCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->SFCCount);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "DBCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->DBCount);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp,&resp_index, "SDBCount");
            ei_encode_long(resp, &resp_index, ((TS7BlocksList *)data)->SDBCount);

            ei_encode_empty_list(resp, &resp_index);     
        break;

        case 10: //TS7BlockInfo
            ei_encode_list_header(resp, &resp_index, data_len);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "BlkType");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->BlkType);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "BlkNumber");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->BlkNumber);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "BlkLang");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->BlkLang);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "BlkFlags");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->BlkFlags);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "MC7Size");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->MC7Size);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "LoadSize");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->LoadSize);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "LocalData");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->LocalData);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "SBBLength");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->SBBLength);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "CheckSum");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->CheckSum);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Version");
            ei_encode_long(resp, &resp_index, ((TS7BlockInfo *)data)->Version);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "CodeDate");
            ei_encode_binary(resp, &resp_index, ((TS7BlockInfo *)data)->CodeDate, 11);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "IntfDate");
            ei_encode_binary(resp, &resp_index, ((TS7BlockInfo *)data)->IntfDate, 11);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Author");
            ei_encode_binary(resp, &resp_index, ((TS7BlockInfo *)data)->Author, 9);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Family");
            ei_encode_binary(resp, &resp_index, ((TS7BlockInfo *)data)->Family, 9);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Header");
            ei_encode_binary(resp, &resp_index, ((TS7BlockInfo *)data)->Header, 9);

            ei_encode_empty_list(resp, &resp_index);
        break;
        
        case 11: //TS7OrderCode
            version[0] = ((TS7OrderCode *)data)->V1 + 0x30;
            version[1] = '.';
            version[2] = ((TS7OrderCode *)data)->V2 + 0x30;
            version[3] = '.';
            version[4] = ((TS7OrderCode *)data)->V3 + 0x30;
            ei_encode_list_header(resp, &resp_index, data_len);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Code");
            ei_encode_binary(resp, &resp_index, ((TS7OrderCode *)data)->Code, 20);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Version");
            ei_encode_binary(resp, &resp_index, version, sizeof(version));
            
            ei_encode_empty_list(resp, &resp_index);        
        break;

        case 12:    //TS7CpuInfo
            ei_encode_list_header(resp, &resp_index, data_len);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "ModuleTypeName");
            ei_encode_binary(resp, &resp_index, ((TS7CpuInfo *)data)->ModuleTypeName, 33);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "SerialNumber");
            ei_encode_binary(resp, &resp_index, ((TS7CpuInfo *)data)->SerialNumber, 25);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "ASName");
            ei_encode_binary(resp, &resp_index, ((TS7CpuInfo *)data)->ASName, 25);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Copyright");
            ei_encode_binary(resp, &resp_index, ((TS7CpuInfo *)data)->Copyright, 27);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "ModuleName");
            ei_encode_binary(resp, &resp_index, ((TS7CpuInfo *)data)->ModuleName, 25);
            
            ei_encode_empty_list(resp, &resp_index);    
        break;

        case 13:    //TS7CpInfo
            ei_encode_list_header(resp, &resp_index, data_len);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "MaxPduLengt");
            ei_encode_long(resp, &resp_index, ((TS7CpInfo *)data)->MaxPduLengt);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "MaxConnections");
            ei_encode_long(resp, &resp_index, ((TS7CpInfo *)data)->MaxConnections);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "MaxMpiRate");
            ei_encode_long(resp, &resp_index, ((TS7CpInfo *)data)->MaxMpiRate);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "MaxBusRate");
            ei_encode_long(resp, &resp_index, ((TS7CpInfo *)data)->MaxBusRate);
            
            ei_encode_empty_list(resp, &resp_index);    
        break;

        case 14: // tm            
            ei_encode_map_header(resp, &resp_index, data_len);

            ei_encode_atom(resp, &resp_index, "tm_sec");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_sec);
            
            ei_encode_atom(resp, &resp_index, "tm_min");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_min);
            
            ei_encode_atom(resp, &resp_index, "tm_hour");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_hour);
            
            ei_encode_atom(resp, &resp_index, "tm_mday");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_mday);

            ei_encode_atom(resp, &resp_index, "tm_mon");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_mon);
            
            ei_encode_atom(resp, &resp_index, "tm_year");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_year);
            
            ei_encode_atom(resp, &resp_index, "tm_wday");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_wday);
            
            ei_encode_atom(resp, &resp_index, "tm_yday");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_yday);

            ei_encode_atom(resp, &resp_index, "tm_isdst");
            ei_encode_long(resp, &resp_index, ((tm *)data)->tm_isdst);
        break;

        case 15: //TS7Protection
            ei_encode_list_header(resp, &resp_index, data_len);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "sch_schal");
            ei_encode_long(resp, &resp_index, ((TS7Protection *)data)->sch_schal);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "sch_par");
            ei_encode_long(resp, &resp_index, ((TS7Protection *)data)->sch_par);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "sch_rel");
            ei_encode_long(resp, &resp_index, ((TS7Protection *)data)->sch_rel);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "bart_sch");
            ei_encode_long(resp, &resp_index, ((TS7Protection *)data)->bart_sch);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "anl_sch");
            ei_encode_long(resp, &resp_index, ((TS7Protection *)data)->anl_sch);
            
            ei_encode_empty_list(resp, &resp_index);
        break;

        case 16: //error code
            code = *(uint32_t *) data; 
            int index_s7 = code / 0x100000;
            int index_iso = (code & 0x000F0000)/ 0x10000;
            int index_tcp = (code & 0xFFFF);
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
        break;

        case 17: //PDU
            ei_encode_list_header(resp, &resp_index, data_len);
            
            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Requested");
            ei_encode_long(resp, &resp_index, ((int *)data)[0]);

            ei_encode_tuple_header(resp, &resp_index, 2);
            ei_encode_atom(resp, &resp_index, "Negotiated");
            ei_encode_long(resp, &resp_index, ((int *)data)[1]);
            
            ei_encode_empty_list(resp, &resp_index);
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
 * @param reason is an error reason (sended back as an atom)
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
 *  where 'reasons' is a map (%{es7: atom/nil, eiso: atom/nil, etcp: int/nil}), 
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
        errx(EXIT_FAILURE, ":connect_to requires a 3-tuple, term_size = %d", term_size);

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
        errx(EXIT_FAILURE, ":set_connection_params requires a 3-tuple, term_size = %d", term_size);

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
        errx(EXIT_FAILURE, ":set_params requires a 2-tuple, term_size = %d", term_size);

    char ind_param;
    if (ei_decode_char(req, req_index, &ind_param) < 0) {
        send_error_response("einval");
        return;
    }

    long long data;
    if (ei_decode_longlong(req, req_index, &data) < 0) {
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
        errx(EXIT_FAILURE, ":read_area requires a 5-tuple, term_size = %d", term_size);

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
        errx(EXIT_FAILURE, ":write_area requires a 6-tuple, term_size = %d", term_size);

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
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*amount))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*amount), bin_size);
    
    int result = Cli_WriteArea(Client, (int)area, (int)db_number, (int)start, (int)amount, (int)data_type, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  This is a lean function of Cli_ReadArea() to read PLC's DB.
 *  It simply internally calls Cli_ReadArea() with
 *      -   Area = S7AreaDB.
 *      -   WordLen = S7WLByte.
*/
static void handle_db_read(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":db_read requires a 3-tuple, term_size = %d", term_size);

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

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    int result = Cli_DBRead(Client, (int)db_number, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is a lean function of Cli_WriteArea() to read PLC's DB.
 *  It simply internally calls Cli_WriteArea() with
 *      -   Area = S7AreaDB.
 *      -   WordLen = S7WLByte.
*/
static void handle_db_write(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 4)
        errx(EXIT_FAILURE, ":db_write requires a 4-tuple, term_size = %d", term_size);

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

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*size))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*size), bin_size);
    
    int result = Cli_DBWrite(Client, (int)db_number, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  This is a lean function of Cli_ReadArea() to read PLC's outputs processes.
 *  It simply internally calls Cli_ReadArea() with
 *      -   Area = S7AreaPA.
 *      -   WordLen = S7WLByte.
*/
static void handle_ab_read(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":ab_read requires a 2-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    int result = Cli_ABRead(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is a lean function of Cli_WriteArea() to read PLC's outputs processes.
 *  It simply internally calls Cli_WriteArea() with
 *      -   Area = S7AreaPA.
 *      -   WordLen = S7WLByte.
*/
static void handle_ab_write(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":ab_write requires a 3-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*size))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*size), bin_size);
    
    int result = Cli_ABWrite(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  This is a lean function of Cli_ReadArea() to read PLC's innuts processes.
 *  It simply internally calls Cli_ReadArea() with
 *      -   Area = S7AreaPE.
 *      -   WordLen = S7WLByte.
*/
static void handle_eb_read(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":eb_read requires a 2-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    int result = Cli_EBRead(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is a lean function of Cli_WriteArea() to read PLC's inputs processes.
 *  It simply internally calls Cli_WriteArea() with
 *      -   Area = S7AreaPE.
 *      -   WordLen = S7WLByte.
*/
static void handle_eb_write(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":eb_write requires a 3-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*size))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*size), bin_size);
    
    int result = Cli_EBWrite(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  This is a lean function of Cli_ReadArea() to read PLC's Merkers.
 *  It simply internally calls Cli_ReadArea() with
 *      -   Area = S7AreaMK.
 *      -   WordLen = S7WLByte.
*/
static void handle_mb_read(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":mb_read requires a 2-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    int result = Cli_MBRead(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is a lean function of Cli_WriteArea() to read PLC's Merkers.
 *  It simply internally calls Cli_WriteArea() with
 *      -   Area = S7AreaMK.
 *      -   WordLen = S7WLByte.
*/
static void handle_mb_write(const char *req, int *req_index)
{
    const char data_len = 1;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":mb_write requires a 3-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*size))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*size), bin_size);
    
    int result = Cli_MBWrite(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  This is a lean function of Cli_ReadArea() to read PLC's Timers.
 *  It simply internally calls Cli_ReadArea() with
 *      -   Area = S7AreaTM.
 *      -   WordLen = S7WLTimer.
*/
static void handle_tm_read(const char *req, int *req_index)
{
    const char data_len = 2;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":tm_read requires a 2-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    int result = Cli_TMRead(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is a lean function of Cli_WriteArea() to read PLC's Timers.
 *  It simply internally calls Cli_WriteArea() with
 *      -   Area = S7AreaTM.
 *      -   WordLen = S7WLTimer.
*/
static void handle_tm_write(const char *req, int *req_index)
{
    const char data_len = 2;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":tm_write requires a 3-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*size))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*size), bin_size);
    
    int result = Cli_TMWrite(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_ok_response();
}

/**
 *  This is a lean function of Cli_ReadArea() to read PLC's Counters.
 *  It simply internally calls Cli_ReadArea() with
 *      -   Area = S7AreaCT.
 *      -   WordLen = S7WLCounter.
*/
static void handle_ct_read(const char *req, int *req_index)
{
    const char data_len = 2;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":ct_read requires a 2-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    int result = Cli_CTRead(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is a lean function of Cli_WriteArea() to read PLC's Counter.
 *  It simply internally calls Cli_WriteArea() with
 *      -   Area = S7AreaCT.
 *      -   WordLen = S7WLCounter.
*/
static void handle_ct_write(const char *req, int *req_index)
{
    const char data_len = 2;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":ct_write requires a 3-tuple, term_size = %d", term_size);

    unsigned long start;
    if (ei_decode_ulong(req, req_index, &start) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[data_len*size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != (data_len*size))
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", (data_len*size), bin_size);
    
    int result = Cli_CTWrite(Client, (int)start, (int)size, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, sizeof(data));
}

/**
 *  This is function allows to read different kind of variables from a
 *  PLC in a single call. With it you can read DB, Inputs, Outputs, Merkers
 *  Timers and Counters.
*/
static void handle_read_multi_vars(const char *req, int *req_index)
{
    unsigned long i_struct;
    int i_key;
    const unsigned char n_keys = 5;
    int term_type;
    int term_size;
    long bin_size;
    byte data_len;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":read_multi_vars requires a 2-tuple, term_size = %d", term_size);

    unsigned long n_vars;
    if (ei_decode_ulong(req, req_index, &n_vars) < 0) {
        send_error_response("einval");
        return;
    }

    if(ei_decode_list_header(req, req_index, &term_size) < 0 || 
        term_size != n_vars)
        errx(EXIT_FAILURE, ":read_multi_vars inconsistent argument size n_vars = %ld, n_maps = %d",
        n_vars, term_size);
    
    TS7DataItem Items[n_vars];
    byte *data_ptrs[n_vars];

    for(i_struct = 0; i_struct < n_vars; i_struct++) 
    {
        if(ei_decode_map_header(req, req_index, &term_size) < 0 || 
        term_size != n_keys)
        errx(EXIT_FAILURE, ":read_multi_vars inconsistent argument size n_keys = %d, arity = %d",
        n_keys, term_size);
        
        for(i_key = 0; i_key < n_keys; i_key++)
        {
            char atom[10];
            if (ei_decode_atom(req, req_index, atom) < 0) {
                send_error_response("einval");
                return;
            }
            
            unsigned long value;
            if (ei_decode_ulong(req, req_index, &value) < 0) {
                send_error_response("einval");
                return;
            }
            
            if(!strcmp(atom, "amount"))
                Items[i_struct].Amount = (int)value;            
            else if(!strcmp(atom, "word_len"))
            {
                Items[i_struct].WordLen = (int)value;
                switch(value)
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
                        errx(EXIT_FAILURE, "inconsistent data_type = %ld", value);
                    break;
                }
            }
            else if(!strcmp(atom, "db_number")) 
                Items[i_struct].DBNumber = (int)value;
            else if(!strcmp(atom, "start")) 
                Items[i_struct].Start = (int)value;
            else if(!strcmp(atom, "area")) 
                Items[i_struct].Area = (int)value;
            else
                errx(EXIT_FAILURE, ":read_multi_vars invalid");            
        } 
        data_ptrs[i_struct] = (byte *) malloc(Items[i_struct].Amount*data_len);
        Items[i_struct].pdata = data_ptrs[i_struct];
    }
    //errx(EXIT_FAILURE, ":read_multi_vars invalid %d", 232);            
    int result = Cli_ReadMultiVars(Client, &Items[0], n_vars);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        for(i_struct = 0; i_struct < n_vars; i_struct++) 
            free(data_ptrs[i_struct]);
        return;
    }    
                
    send_data_response(&Items, 7, n_vars);
    for(i_struct = 0; i_struct < n_vars; i_struct++) 
        free(data_ptrs[i_struct]);
}

/**
 *  This is function allows to write different kind of variables from a
 *  PLC in a single call. With it you can read DB, Inputs, Outputs, Merkers
 *  Timers and Counters.
*/
static void handle_write_multi_vars(const char *req, int *req_index)
{
    unsigned long i_struct;
    int i_key;
    const unsigned char n_keys = 6;
    int term_type;
    int term_size;
    long bin_size;
    unsigned long value;
    unsigned char data_len;
    unsigned char tmp_ind;
    byte data[256];

    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":write_multi_vars requires a 2-tuple, term_size = %d", term_size);

    unsigned long n_vars;
    if (ei_decode_ulong(req, req_index, &n_vars) < 0) {
        send_error_response("einval");
        return;
    }

    if(ei_decode_list_header(req, req_index, &term_size) < 0 || 
        term_size != n_vars)
        errx(EXIT_FAILURE, ":write_multi_vars inconsistent argument size n_vars = %ld, n_maps = %d",
        n_vars, term_size);
    
    TS7DataItem Items[n_vars];
    byte *data_ptrs[n_vars];

    for(i_struct = 0; i_struct < n_vars; i_struct++) 
    {
        if(ei_decode_map_header(req, req_index, &term_size) < 0 || 
        term_size != n_keys)
        errx(EXIT_FAILURE, ":write_multi_vars inconsistent argument size n_keys = %d, arity = %d",
        n_keys, term_size);
        
        for(i_key = 0; i_key < n_keys; i_key++)
        {
            char atom[10];
            if (ei_decode_atom(req, req_index, atom) < 0) {
                send_error_response("einval");
                return;
            }
            
            if(!strcmp(atom, "data")) 
            {
                if(ei_decode_binary(req, req_index, data, &bin_size) < 0)
                {
                    send_error_response("einval_g");
                    return;
                }
            }
            else
            {
                if (ei_decode_ulong(req, req_index, &value) < 0) {
                    send_error_response("einval_2");
                    return;
                }
            }
            if(!strcmp(atom, "amount"))
                Items[i_struct].Amount = (int)value;            
            else if(!strcmp(atom, "word_len"))
            { 
                Items[i_struct].WordLen = (int)value;
                switch(value)
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
                        errx(EXIT_FAILURE, "write_multi_vars inconsistent data_type = %ld", value);
                    break;
                }
            }
            else if(!strcmp(atom, "db_number")) 
                Items[i_struct].DBNumber = (int)value;
            else if(!strcmp(atom, "start")) 
                Items[i_struct].Start = (int)value;
            else if(!strcmp(atom, "area")) 
                Items[i_struct].Area = (int)value;      
        } 
        
        if(bin_size != (Items[i_struct].Amount*data_len))
            errx(EXIT_FAILURE, ":write_multi_vars binary inconsistent, expected size = %d, real = %ld",
            (Items[i_struct].Amount*data_len), bin_size); 

        data_ptrs[i_struct] = (byte *) malloc(Items[i_struct].Amount*data_len);
        
        for(tmp_ind=0; tmp_ind < Items[i_struct].Amount*data_len; tmp_ind ++)
            data_ptrs[i_struct][tmp_ind] = data[tmp_ind];
        
        Items[i_struct].pdata = data_ptrs[i_struct];
    }

    int result = Cli_WriteMultiVars(Client, &Items[0], n_vars);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        for(i_struct = 0; i_struct < n_vars; i_struct++) 
           free(data_ptrs[i_struct]);
        return;
    }    
    send_ok_response();
    for(i_struct = 0; i_struct < n_vars; i_struct++) 
        free(data_ptrs[i_struct]);
}

// Directory functions

/**
 *  This function returns the AG blocks amount divided by type
*/
static void handle_list_blocks(const char *req, int *req_index)
{
    const byte data_len = 7; //n items in TS7BlocksOfType struct
    TS7BlocksList List;
    int result = Cli_ListBlocks(Client, &List);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    //send TS7BlocksOfType
    send_data_response(&List, 9, data_len);
}

/**
 *  This function returns the AG list of a specified block type. 
 *  (Not sure the datatype of data)
*/
static void handle_list_blocks_of_type(const char *req, int *req_index)
{    
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":list_blocks_of_type requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long block_type;
    if (ei_decode_ulong(req, req_index, &block_type) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long n_items;
    if (ei_decode_ulong(req, req_index, &n_items) < 0) {
        send_error_response("einval");
        return;
    }
    int items_count = (int) n_items;    //check for a better way of casting...
    short unsigned int data[items_count];
    int result = Cli_ListBlocksOfType(Client, (int)block_type, &data, &items_count);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    //send TS7BlocksOfType b
    send_data_response(data, 8, items_count);
}

/**
 *  Return detail information about an AG given block.
 * 
 *  This function is very useful if you nead to read or write data in a DB 
 *  which you do not know the size in advance (see pg 127).
 * 
 *  This function is used internally by Cli_DBGet().
*/
static void handle_get_ag_block_info(const char *req, int *req_index)
{
    const byte data_len = 15;

    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":get_ag_block_info requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long block_type;
    if (ei_decode_ulong(req, req_index, &block_type) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long block_num;
    if (ei_decode_ulong(req, req_index, &block_num) < 0) {
        send_error_response("einval");
        return;
    }
    
    TS7BlockInfo block_ag_info;
    int result = Cli_GetAgBlockInfo(Client, (int)block_type, (int)block_num, &block_ag_info);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    //send TS7BlockInfo
    send_data_response(&block_ag_info, 10, data_len);
}

/**
 *  Return detailed information about a block present in a user buffer.
 *  This function is usually used in conjunction with Cli_FullUpload().
 * 
 *  An uploaded a block saved to disk, could be loaded in a user buffer
 *  and checked with this function. 
*/
static void handle_get_pg_block_info(const char *req, int *req_index)
{
    const byte data_len = 15;   //items in the TS7BlockInfo struct

    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":get_pg_block_info requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    byte data[size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != size)
        errx(EXIT_FAILURE, ":get_pg_block_info binary inconsistent, expected size = %ld, real = %ld",
         size, bin_size);

    TS7BlockInfo block_ag_info;
    int result = Cli_GetPgBlockInfo(Client, &data, &block_ag_info, (int)size);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    //send TS7BlockInfo
    send_data_response(&block_ag_info, 10, data_len);
}

//    Block oriented functions

/**
 *  Uploads a block from AG. (gets a block from PLC)
 *  The whole block (including header and footer) is copied into the user buffer.
*/
static void handle_full_upload(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":full_upload requires a 3-tuple, term_size = %d", term_size);

    unsigned long block_type;
    if (ei_decode_ulong(req, req_index, &block_type) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long block_num;
    if (ei_decode_ulong(req, req_index, &block_num) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    byte data[size];
    int length = (int)size;    //check for a better way of casting...
    int result = Cli_FullUpload(Client, (int)block_type, (int)block_num, &data, &length);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_data_response(data, 5, (int)size);
}

/**
 *  Uploads a block body from AG. (gets a block from PLC)
 *  The whole block body (including header and footer) is copied into the user buffer.
*/
static void handle_upload(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":upload requires a 3-tuple, term_size = %d", term_size);

    unsigned long block_type;
    if (ei_decode_ulong(req, req_index, &block_type) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long block_num;
    if (ei_decode_ulong(req, req_index, &block_num) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    byte data[size];
    int length = (int)size;    //check for a better way of casting...
    int result = Cli_Upload(Client, (int)block_type, (int)block_num, &data, &length);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_data_response(data, 5, (int)size);
}

/**
 *  Download block from AG. (gets a block to the  PLC)
 *  The whole block body (including header and footer) must be available into the user buffer.
*/
static void handle_download(const char *req, int *req_index)
{
    char data_len;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 3)
        errx(EXIT_FAILURE, ":download requires a 3-tuple, term_size = %d", term_size);
    
    unsigned long block_num;
    if (ei_decode_ulong(req, req_index, &block_num) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    byte data[size];
    long bin_size;
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != size)
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", size, bin_size);

    int result = Cli_Download(Client, (int)block_num, &data, (int)size);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_ok_response();
}

/**
 *  Deletes block into AG.
 *  (There is an undo function available).
*/
static void handle_delete(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":delete requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long block_type;
    if (ei_decode_ulong(req, req_index, &block_type) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned long block_num;
    if (ei_decode_ulong(req, req_index, &block_num) < 0) {
        send_error_response("einval");
        return;
    }   

    int result = Cli_Delete(Client, (int)block_num, (int)block_type);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_ok_response();
}

/**
 *  Uploads a DB from AG. (gets a DB from PLC)
 *  This function is equivalent to Cli_Upload() with BlockType = Block_DB 
 *  but it uses a different approach so it's  not subject to the security level set.
 *  Only data is uploaded. (typically the size is 65536)
*/
static void handle_db_get(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":db_get requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long db_number;
    if (ei_decode_ulong(req, req_index, &db_number) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    byte data[size];
    int length = (int)size;    //check for a better way of casting...
    int result = Cli_DBGet(Client, (int)db_number, &data, &length);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_data_response(data, 8, (int)size);
}

/**
 *  Fill a DB in AG with a given byte without the need of specifying its size.
*/
static void handle_db_fill(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":db_fill requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long db_number;
    if (ei_decode_ulong(req, req_index, &db_number) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long fill_char;
    if (ei_decode_ulong(req, req_index, &fill_char) < 0) {
        send_error_response("einval");
        return;
    }
    
    int result = Cli_DBFill(Client, (int)db_number, (int)fill_char);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_ok_response();
}

//    Date/Time functions

/**
 *  Reads PLC date and time.
*/
static void handle_get_plc_date_time(const char *req, int *req_index)
{
    tm date;
    int result = Cli_GetPlcDateTime(Client, &date);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    date.tm_mon++;
    date.tm_year += 1900;
    send_data_response(&date, 14, 9);
}

/**
 *  Sets PLC date and time.
*/
static void handle_set_plc_date_time(const char *req, int *req_index)
{
    tm date;
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 9)
        errx(EXIT_FAILURE, ":set_plc_date_time requires a 9-tuple, term_size = %d", term_size);

    unsigned long tm_sec;
    if (ei_decode_ulong(req, req_index, &tm_sec) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_sec = tm_sec;

    unsigned long tm_min;
    if (ei_decode_ulong(req, req_index, &tm_min) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_min = tm_min;

    unsigned long tm_hour;
    if (ei_decode_ulong(req, req_index, &tm_hour) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_hour = tm_hour;

    unsigned long tm_mday;
    if (ei_decode_ulong(req, req_index, &tm_mday) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_mday = tm_mday;

    unsigned long tm_mon;
    if (ei_decode_ulong(req, req_index, &tm_mon) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_mon = tm_mon - 1;

    unsigned long tm_year;
    if (ei_decode_ulong(req, req_index, &tm_year) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_year = tm_year - 1900;

    unsigned long tm_wday;
    if (ei_decode_ulong(req, req_index, &tm_wday) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_wday = tm_wday;

    unsigned long tm_yday;
    if (ei_decode_ulong(req, req_index, &tm_yday) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_yday = tm_yday;

    unsigned long tm_isdst;
    if (ei_decode_ulong(req, req_index, &tm_isdst) < 0) {
        send_error_response("einval");
        return;
    }
    date.tm_isdst = tm_isdst;
    
    int result = Cli_SetPlcDateTime(Client, &date);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_ok_response();
}

/**
 *  Sets PLC date and time in accord to the PC system Date/Time.
*/
static void handle_set_plc_system_date_time(const char *req, int *req_index)
{
    int result = Cli_SetPlcSystemDateTime(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_ok_response();
}

//    System info functions

/**
 *  Reads a partial list of given ID and INDEX
 *  See System Software for S7-300/400 System and Standard Functions 
 *  Volume 1 and Volume 2 for ID and INDEX info (chapter 13.3 ), look for 
 *  TIA Portal Information Systems for DR data type.
*/
static void handle_read_szl(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":read_szl requires a 2-tuple, term_size = %d", term_size);
    
    unsigned long ID;
    if (ei_decode_ulong(req, req_index, &ID) < 0) {
        send_error_response("einval");
        return;
    }

    unsigned long Index;
    if (ei_decode_ulong(req, req_index, &Index) < 0) {
        send_error_response("einval");
        return;
    }

    TS7SZL data;
    int size = sizeof(data);
    int result = Cli_ReadSZL(Client, (int)ID, (int)Index, &data, &size);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    //it maybe size 
    int dim = data.Header.LENTHDR*data.Header.N_DR;
    send_data_response(data.Data, 5, (int)dim);
}

/**
 *  Reads the directory of the partial list
 *  See System Software for S7-300/400 System and Standard Functions 
 *  Volume 1 and Volume 2 for ID and INDEX info (chapter 13.3 ), not sure
 *  how to use the function.
*/
static void handle_read_szl_list(const char *req, int *req_index)
{
    TS7SZLList data;
    int size = sizeof(data);
    int result = Cli_ReadSZLList(Client, &data, &size);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    //it maybe size 
    send_data_response(data.List, 8, (int)size);
}

/**
 *  Gets CPU order code and version info.
*/
static void handle_get_order_code(const char *req, int *req_index)
{
    TS7OrderCode data;
    int result = Cli_GetOrderCode(Client, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    //sends TS7OrderCode
    send_data_response(&data, 11, 2);
}

/**
 *  Gets CPU module name, serial number and other info.
*/
static void handle_get_cpu_info(const char *req, int *req_index)
{
    TS7CpuInfo data;
    int result = Cli_GetCpuInfo(Client, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    //sends TS7CpuInfo
    send_data_response(&data, 12, 5);
}

/**
 *  Gets CP (commnication processor) info.
*/
static void handle_get_cp_info(const char *req, int *req_index)
{
    TS7CpInfo data;
    int result = Cli_GetCpInfo(Client, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    //sends TS7CpuInfo
    send_data_response(&data, 13, 4);
}

// PLC control functions

/**
 *  Puts the CPU in RUN mode performing an HOT START
*/
static void handle_plc_hot_start(const char *req, int *req_index)
{
    int result = Cli_PlcHotStart(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Puts the CPU in RUN mode performing an COLD START
*/
static void handle_plc_cold_start(const char *req, int *req_index)
{
    int result = Cli_PlcColdStart(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Puts the CPU in STOP mode.
*/
static void handle_plc_stop(const char *req, int *req_index)
{
    int result = Cli_PlcStop(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Performs the Copy Ram to Rom action.
 *  (CPU must be in STOP mode)
*/
static void handle_copy_ram_to_rom(const char *req, int *req_index)
{
    unsigned long timeout;
    if (ei_decode_ulong(req, req_index, &timeout) < 0) {
        send_error_response("einval");
        return;
    }

    int result = Cli_CopyRamToRom(Client, (int)timeout);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Performs the Memmory compress action.
 *  (CPU must be in STOP mode)
*/
static void handle_compress(const char *req, int *req_index)
{
    unsigned long timeout;
    if (ei_decode_ulong(req, req_index, &timeout) < 0) {
        send_error_response("einval");
        return;
    }

    int result = Cli_Compress(Client, (int)timeout);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Returns the CPU status (running/stopped).
*/
static void handle_get_plc_status(const char *req, int *req_index)
{
    int status;
    int result = Cli_GetPlcStatus(Client, &status);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    switch(status)
    {
        case 0x00:
            send_data_response("S7CpuStatusUnknown", 6, 0);
        break;
        
        case 0x04:
            send_data_response("S7CpuStatusStop", 6, 0);
        break;

        case 0x08:
            send_data_response("S7CpuStatusRun", 6, 0);
        break;

        default:
            errx(EXIT_FAILURE, ":get_plc_status unknown snap7 status = %d", status);
        break;
    }
}

//  Security function

/**
 *  Send the password (8 char string) to the PLC to meet its security level,
 *  (a greater password size will be timmed, and a smaller one will be "right 
 *  space padded").
*/
static void handle_set_session_password(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    char password[13];
    long binary_len;
    if (ei_get_type(req, req_index, &term_type, &term_size) < 0 ||
            term_type != ERL_BINARY_EXT ||
            term_size >= (int) sizeof(password) ||
            ei_decode_binary(req, req_index, password, &binary_len) < 0) {
        // The name is almost certainly too long, so report that it
        // doesn't exist.
        send_error_response("enoent");
        return;
    }
    password[term_size] = '\0';
    
    int result = Cli_SetSessionPassword(Client, password);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Clears the passord set for the current session (logout).
*/
static void handle_clear_session_password(const char *req, int *req_index)
{    
    int result = Cli_ClearSessionPassword(Client);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_ok_response();
}

/**
 *  Gets the CPU protection level info.
*/
static void handle_get_protection(const char *req, int *req_index)
{    
    TS7Protection data;
    int result = Cli_GetProtection(Client, &data);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
    
    send_data_response(&data, 15, 5);
}

//  Low level functions

/**
 *  Exchanges a given S7 PDU (protocol data unit) with the CPU,
*/
static void handle_iso_exchange_buffer(const char *req, int *req_index)
{
    int term_type;
    int term_size;
    if(ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
        term_size != 2)
        errx(EXIT_FAILURE, ":db_write requires a 4-tuple, term_size = %d", term_size);

    unsigned long size;
    if (ei_decode_ulong(req, req_index, &size) < 0) {
        send_error_response("einval");
        return;
    }
    
    unsigned char data[1024];
    long bin_size;
    int length = (int)size;    //check for a better way of casting...
    if(ei_decode_binary(req, req_index, data, &bin_size) < 0 ||
        bin_size != size)
        errx(EXIT_FAILURE, "binary inconsistent, expected size = %ld, real = %ld", size, bin_size);
    
    int result = Cli_IsoExchangeBuffer(Client, &data, &length);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }
            
    send_data_response(data, 5, size);
}

//  Miscellaneous functions

/**
 *  Returns the last job execution time in milliseconds.
*/
static void handle_get_exec_time(const char *req, int *req_index)
{
    int Time;
    int result = Cli_GetExecTime(Client, &Time);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_data_response(&Time, 2, 0);
}

/**
 *  Returns the last job result.
*/
static void handle_get_last_error(const char *req, int *req_index)
{
    int error;
    int result = Cli_GetLastError(Client, &error);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_data_response(&error, 16, 0);
}

/**
 *  Returns info about the PDU length
*/
static void handle_get_pdu_length(const char *req, int *req_index)
{
    int req_neg[2];
    int result = Cli_GetPduLength(Client, &req_neg[0], &req_neg[1]);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    send_data_response(req_neg, 17, 2);
}

/**
 *  Returns the connection status
*/
static void handle_get_connected(const char *req, int *req_index)
{
    int status;
    int result = Cli_GetConnected(Client, &status);
    if (result != 0){
        //the paramater was invalid.
        send_snap7_errors(result);
        return;
    }

    if(status != 0)
        send_data_response("true", 6, 0);
    else
        send_data_response("false", 6, 0);    
}

static void handle_test(const char *req, int *req_index)
{
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
    {"test", handle_test},
    {"set_connection_type", handle_set_connection_type},
    {"connect_to", handle_connect_to},
    {"set_connection_params", handle_set_connection_params},
    {"connect", handle_connect},
    {"disconnect", handle_disconnect},
    {"get_params", handle_get_params},
    {"set_params", handle_set_params},
    {"read_area", handle_read_area},
    {"write_area", handle_write_area},
    {"db_read", handle_db_read},
    {"db_write", handle_db_write},
    {"ab_read", handle_ab_read},
    {"ab_write", handle_ab_write},
    {"eb_read", handle_eb_read},
    {"eb_write", handle_eb_write},
    {"mb_read", handle_mb_read},
    {"mb_write", handle_mb_write},
    {"tm_read", handle_tm_read},
    {"tm_write", handle_tm_write},
    {"ct_read", handle_ct_read},
    {"ct_write", handle_ct_write},
    {"read_multi_vars", handle_read_multi_vars},
    {"write_multi_vars", handle_write_multi_vars},
    {"list_blocks", handle_list_blocks},
    {"list_blocks_of_type", handle_list_blocks_of_type},
    {"get_ag_block_info", handle_get_ag_block_info},
    {"get_pg_block_info", handle_get_pg_block_info},
    {"full_upload", handle_full_upload},
    {"upload", handle_upload},
    {"download", handle_download},
    {"delete", handle_delete},
    {"db_get", handle_db_get},
    {"db_fill", handle_db_fill},
    {"get_plc_date_time", handle_get_plc_date_time},
    {"set_plc_date_time", handle_set_plc_date_time},
    {"set_plc_system_date_time", handle_set_plc_system_date_time},
    {"read_szl", handle_read_szl},
    {"read_szl_list", handle_read_szl_list},
    {"get_order_code", handle_get_order_code},
    {"get_cpu_info", handle_get_cpu_info},
    {"get_cp_info", handle_get_cp_info},
    {"plc_hot_start", handle_plc_hot_start},
    {"plc_cold_start", handle_plc_cold_start},
    {"plc_stop", handle_plc_stop},
    {"copy_ram_to_rom", handle_copy_ram_to_rom},
    {"compress", handle_compress},
    {"get_plc_status", handle_get_plc_status},
    {"set_session_password", handle_set_session_password},
    {"clear_session_password", handle_clear_session_password},
    {"get_protection", handle_get_protection},
    {"iso_exchange_buffer", handle_iso_exchange_buffer},
    {"get_exec_time", handle_get_exec_time},
    {"get_last_error", handle_get_last_error},
    {"get_pdu_length", handle_get_pdu_length},
    {"get_connected", handle_get_connected},
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