#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

#include <usb.h>
#include <assert.h>

/* ID ISC.PR100 */
#define RFID_VENDOR  0x0AB1
#define RFID_PRODUCT 0x0002

#define TIMEOUT      10000

typedef struct rfid_s {
    usb_dev_handle *dev;
} rfid_t;

rfid_t *rfid_open(int deviceno) {
    int    num = 0;
    rfid_t *rfid;
    struct usb_bus *bus;
    struct usb_device *dev;

    if (!usb_busses) {
        usb_init();
        usb_find_busses();
        usb_find_devices();
    }

    if (!usb_busses) {
        fprintf(stderr, "no usb bus found?\n");
        return NULL;
    }
        
    for (bus = usb_busses; bus; bus = bus->next) {
        for (dev = bus->devices; dev; dev = dev->next) {
            if (dev->descriptor.idVendor  == RFID_VENDOR &&
                dev->descriptor.idProduct == RFID_PRODUCT) {
                if (num++ == deviceno)
                    goto found;
            }
        }
    }
    fprintf(stderr, "device %d not found\n", deviceno);
    return NULL;

found:
    rfid = (rfid_t*)malloc(sizeof(rfid_t));

    if (!rfid) {
        fprintf(stderr, "cannot allocate memory\n");
        return NULL;
    }

    rfid->dev = usb_open(dev);
    if (!rfid->dev) {
        fprintf(stderr, "cannot open device %d: %s\n", deviceno, usb_strerror());
        free(rfid);
        return NULL;
    }

    usb_detach_kernel_driver_np(rfid->dev, 1);

    if (usb_claim_interface(rfid->dev, 1) < 0) {
        fprintf(stderr, "claim failed: %s\n", usb_strerror()); 
        usb_close(rfid->dev);
        free(rfid);
        return NULL;
    }
    
    return rfid;
}

int rfid_requestIN(rfid_t *rfid, int req, int value, int index,
                  unsigned char *buf, int buflen) 
{
    int ret;

    assert(rfid);
    assert(rfid->dev);

    ret = usb_control_msg(rfid->dev, USB_ENDPOINT_IN + USB_TYPE_VENDOR,
                          req, value, index, (char*)buf, buflen, TIMEOUT);

    if (ret < 0) {
        fprintf(stderr, "cannot read message: %s\n", usb_strerror());
        return -1;
    }

    return ret;
}

int rfid_requestOUT(rfid_t *rfid, int req, int value, int index,
                  unsigned char *buf, int buflen) 
{
    int ret;
    
    assert(rfid);
    assert(rfid->dev);

    ret = usb_control_msg(rfid->dev, USB_ENDPOINT_OUT + USB_TYPE_VENDOR,
                          req, value, index, (char*)buf, buflen, TIMEOUT);

    if (ret < 0) {
        fprintf(stderr, "cannot read message: %s\n", usb_strerror());
        return -1;
    }

    return ret;
}

void rfid_close(rfid_t *rfid) {
    assert(rfid);
    assert(rfid->dev);

    usb_close(rfid->dev);
    free(rfid);
}
