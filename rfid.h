#ifndef RFID_H
#define RFID_H

typedef struct rfid_s rfid_t;

rfid_t *rfid_open(int deviceno);
int rfid_requestIN (rfid_t *rfid, int req, int value, int index, unsigned char *buf, int buflen);
int rfid_requestOUT(rfid_t *rfid, int req, int value, int index, unsigned char *buf, int buflen);
void rfid_close(rfid_t *rfid);

#endif
