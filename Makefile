LDFLAGS=-lusb

all: rfid

rfid: rfid.o
	$(CC) $< $(LDFLAGS) -o $@

clean:
	rm -f *.o rfid
