#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#include <usb.h>
#include <assert.h>

/* ID ISC.PR100 */
#define RFID_VENDOR  0x0AB1
#define RFID_PRODUCT 0x0002

struct usb_dev_handle *getRFIDdev() {
    struct usb_bus *bus;
    struct usb_device *dev;
    usb_init();
    usb_find_busses();
    usb_find_devices();
    for (bus = usb_busses; bus; bus = bus->next) {
        for (dev = bus->devices; dev; dev = dev->next) {
            if (dev->descriptor.idVendor  == RFID_VENDOR &&
                dev->descriptor.idProduct == RFID_PRODUCT) {
                return usb_open(dev);
            }
        }
    }
    return NULL;
}

int main() {
    int ret;
    usb_dev_handle *rfid = getRFIDdev();

    if (!rfid) {
        fprintf(stderr, "cannot find RFID device\n");
        goto out;
    }

    if ((ret = usb_claim_interface(rfid, 1)) < 0) {
        fprintf(stderr, "claim failed: %d %s\n", ret, usb_strerror()); 
        goto out;
    }

    while (1) {
        unsigned char buf[255];
        ret = usb_control_msg(rfid, USB_ENDPOINT_IN + USB_TYPE_VENDOR,
                0xB0, 0x0000, 0x0100, buf, sizeof(buf), 10000);

        if (ret < 0) {
            fprintf(stderr, "cannot read message: %s\n", usb_strerror());
            goto out;
        }

        assert(ret >= 3);
        assert(buf[2] == 0 || buf[2] == 1);

        if (buf[2] == 0) {
            assert(ret >= 4);
            assert(ret == buf[3] * 10 + 4);

            int tag;
            for (tag = 0; tag < buf[3]; tag++) {
                int ident;
                for (ident = 2; ident < 10; ident++)
                    fprintf(stdout, "%02X", buf[4 + tag * 10 + ident]);
                fprintf(stdout, "\n");
            }
        }
    }

out:        
    if (rfid) usb_close(rfid);
    return 0;
}
