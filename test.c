#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#include <assert.h>

#include "rfid.h"

int main() {
    rfid_t *rfid = rfid_open(0);

    if (!rfid) {
        fprintf(stderr, "cannot open RFID device 0\n");
        return EXIT_FAILURE;
    }

    while (1) {
        unsigned char buf[255];
        int len = rfid_requestIN(rfid, 0xB0, 0x0000, 0x0100, buf, sizeof(buf));

        if (len < 0) 
            break;

        assert(len >= 3);
        assert(buf[2] == 0 || buf[2] == 1);

        if (buf[2] == 0) {
            int tag;

            assert(len >= 4);
            assert(len == buf[3] * 10 + 4);

            for (tag = 0; tag < buf[3]; tag++) {
                int ident;
                for (ident = 2; ident < 10; ident++)
                    fprintf(stdout, "%02X", buf[4 + tag * 10 + ident]);
                fprintf(stdout, "\n");
            }
        }
    }

    rfid_close(rfid);
    return EXIT_SUCCESS;
}
