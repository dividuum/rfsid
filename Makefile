CFLAGS=-Wall -pedantic 

all: test librfid.so

librfid.so: rfid.o
	$(CC) -shared $^ -lusb -o $@

test: test.o librfid.so
	$(CC) $< -L. -lrfid -o $@

doc:
	rdoc 

clean:
	rm -f *.o test *.so
	rm -rf doc
