#include "snap7.h"
#include "erlcmd.h"
#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>
#include <stdio.h>

S7Object Client;

// Utilities for communication 
static const char response_id = 'r';
static const char notification_id = 'n';

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

// Elixir call handlers
//TODO: Modificar para fines prácticos para parsear las opciones permitidas
// static int parse_option_list(const char *req, int *req_index, struct uart_config *config)
// {
//     int term_type;
//     int option_count;
//     if (ei_get_type(req, req_index, &term_type, &option_count) < 0 ||
//             (term_type != ERL_LIST_EXT && term_type != ERL_NIL_EXT)) {
//         debug("expecting option list");
//         return -1;
//     }

//     if (term_type == ERL_NIL_EXT)
//         option_count = 0;
//     else
//         ei_decode_list_header(req, req_index, &option_count);

//     // Go through all of the options
//     for (int i = 0; i < option_count; i++) {
//         int term_size;
//         if (ei_decode_tuple_header(req, req_index, &term_size) < 0 ||
//                 term_size != 2) {
//             debug("expecting kv tuple for options");
//             return -1;
//         }

//         char key[64];
//         if (ei_decode_atom(req, req_index, key) < 0) {
//             debug("expecting atoms for option keys");
//             return -1;
//         }

//         if (strcmp(key, "active") == 0) {
//             int val;
//             if (ei_decode_boolean(req, req_index, &val) < 0) {
//                 debug("active should be a bool");
//                 return -1;
//             }
//             config->active = (val != 0);
//         } else if (strcmp(key, "speed") == 0) {
//             long val;
//             if (ei_decode_long(req, req_index, &val) < 0) {
//                 debug("speed should be an integer");
//                 return -1;
//             }
//             config->speed = val;
//         } else if (strcmp(key, "data_bits") == 0) {
//             long val;
//             if (ei_decode_long(req, req_index, &val) < 0) {
//                 debug("data_bits should be an integer");
//                 return -1;
//             }
//             config->data_bits = val;
//         } else if (strcmp(key, "stop_bits") == 0) {
//             long val;
//             if (ei_decode_long(req, req_index, &val) < 0) {
//                 debug("stop_bits should be an integer");
//                 return -1;
//             }
//             config->stop_bits = val;
//         } else if (strcmp(key, "parity") == 0) {
//             char parity[16];
//             if (ei_decode_atom(req, req_index, parity) < 0) {
//                 debug("parity should be an atom");
//                 return -1;
//             }
//             if (strcmp(parity, "none") == 0) config->parity = UART_PARITY_NONE;
//             else if (strcmp(parity, "even") == 0) config->parity = UART_PARITY_EVEN;
//             else if (strcmp(parity, "odd") == 0) config->parity = UART_PARITY_ODD;
//             else if (strcmp(parity, "space") == 0) config->parity = UART_PARITY_SPACE;
//             else if (strcmp(parity, "mark") == 0) config->parity = UART_PARITY_MARK;
//         } else if (strcmp(key, "flow_control") == 0) {
//             char flow_control[16];
//             if (ei_decode_atom(req, req_index, flow_control) < 0) {
//                 debug("flow_control should be an atom");
//                 return -1;
//             }
//             if (strcmp(flow_control, "none") == 0) config->flow_control = UART_FLOWCONTROL_NONE;
//             else if (strcmp(flow_control, "hardware") == 0) config->flow_control = UART_FLOWCONTROL_HARDWARE;
//             else if (strcmp(flow_control, "software") == 0) config->flow_control = UART_FLOWCONTROL_SOFTWARE;
//         } else {
//             // unknown term
//             ei_skip_term(req, req_index);
//         }
//     }
//     return 0;
// }

/* Snap7 Handlers
 * 
 */
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
{ "test", handle_test },
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
    errx(EXIT_FAILURE, "unknown command: %s", cmd);
}

// int main()
// {
//     //TODO: Configurar cliente

//     struct erlcmd *handler = malloc(sizeof(struct erlcmd));
//     erlcmd_init(handler, handle_elixir_request, NULL);

//     for (;;) {
//         struct pollfd fdset[3];

//         fdset[0].fd = STDIN_FILENO;
//         fdset[0].events = POLLIN;
//         fdset[0].revents = 0;

//         int timeout = -1; // Wait forever unless told by otherwise
//         int count = uart_add_poll_events(uart, &fdset[1], &timeout);

//         int rc = poll(fdset, count + 1, timeout);
//         if (rc < 0) {
//             // Retry if EINTR
//             if (errno == EINTR)
//                 continue;

//             err(EXIT_FAILURE, "poll");
//         }

//         if (fdset[0].revents & (POLLIN | POLLHUP)) {
//             if (erlcmd_process(handler))
//                 break;
//         }

//         // Call uart_process if it added any events
//         if (count)
//             uart_process(uart, &fdset[1]);
//     }

//     // Exit due to Erlang trying to end the process.
//     //
//     if (uart_is_open(uart))
//         uart_flush_all(uart);   
// }

int main()
{
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
    // Call uart_process if it added any events
    
}