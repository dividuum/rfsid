require 'dl/import'
require 'ostruct'

module RFID
    extend DL::Importable
    dlload "./librfid.so"

    extern "rfid_t *rfid_open(int)"
    extern "int     rfid_requestIN (rfid_t *, int, int, int, unsigned char *, int)"
    extern "int     rfid_requestOUT(rfid_t *, int, int, int, unsigned char *, int)"
    extern "void    rfid_close(rfid_t *)"

    module Status
        OK             = 0x00
        NOTRANSPONDER  = 0x01
        WRONGTYPE      = 0x05
        ISOWARN        = 0x95
    end

    class Device
        MAXREQUESTLEN = 255

        def initialize(deviceno = 0)
            @rfid = RFID::rfid_open(deviceno)
            raise "cannot open device" if @rfid.nil?
            if block_given?
                begin
                    yield self
                ensure
                    close
                end
            end
        end

        def requestIN(req, val, idx, len = MAXREQUESTLEN)
            buffer = (" " * len).to_ptr
            len = RFID::rfid_requestIN(@rfid, req, val, idx, buffer, len)
            raise "error sending RFID out request" if len < 0
            raise "reply too small" if len < 3
            received = buffer.to_s(len)
            raise "inconsistent length" unless received[0] == len
            raise "inconsistent type"   unless received[1] == req
            [received[2], received[3..-1]]
        end

        def requestOUT(req, val, idx, data)
            buffer = data.to_ptr
            # data.each_byte {|i| print "%02x " % i}; puts
            len = RFID::rfid_requestOUT(@rfid, req, val, idx, buffer, data.size)
            raise "error sending RFID out request" if len < 0
            raise "short send" unless len == data.size
        end

        def resetCPU
            requestIN(0x63, 0, 0, 3) == [RFID::Status::OK, ""]
        end

        def getFirmWareInfo
            status, buf = requestIN(0x65, 0, 0, 10)
            return nil unless status == RFID::Status::OK
            info = OpenStruct.new
            info.softwareRevision = "%02x-%02x" % [buf[0], buf[1]]
            info.hardwareType     = buf[3]
            info.firmware         = buf[4]
            info.firmwareName     = case info.firmware
                                    when 0x49: "ID ISC.MR100-U"
                                    else       "unknown"
                                    end
            info.transponder      = [buf[5], buf[6]]                                    
            info
        end

        def readSerials
            status, buf = requestIN(0xB0, 0, 0x0100)
            return [] if status == RFID::Status::NOTRANSPONDER
            raise "cannot read serials" unless status == RFID::Status::OK
            serials = []
            numserials = buf[0]
            buf.slice!(0)
            return nil unless buf.size == numserials * 10
            numserials.times do |i|
                serial = OpenStruct.new
                serial.trType = buf[0]
                serial.dsfid  = buf[1]
                serial.snr    = buf[2..9]
                serial.snrHex = buf[2..9].unpack("H*")[0]
                serials << serial
                buf.slice!(0..9)
            end
            serials
        end

        def read(snr, blockOffset = 0, numBlocks = 32)
            raise "invalid address" unless snr.size == 8
            requestOUT(0xB0, 0, 0x2301, snr + [blockOffset, numBlocks].pack("CC"))
            status, buf = requestIN(0xB0, 0, 0x2301)
            if status == 2
                warn "unknown status 2"
                return nil
            end
            return nil if status == RFID::Status::NOTRANSPONDER
            # <numBlocksRead> <blockSize> {0 data3 data2 data1 data0}*
            raise "cannot read data" unless status == RFID::Status::OK
            raise "reply too small"  unless buf.size >= 2
            numBlocksRead = buf[0]
            blockSize     = buf[1]
            buf.slice!(0..1)
            raise "block size inconsistency"  unless buf.size == numBlocksRead * 5
            data = ""
            numBlocksRead.times do 
                data += buf[1..blockSize].reverse
                buf.slice!(0..blockSize)
            end
            [data, numBlocksRead, blockSize]
        end

        def write(snr, data, blockOffset = 0)
            # FIXME: Support fuer Blocksize != 4 einbauen?
            return false unless data.size % 4 == 0
            data.gsub!(/..../) { |b| b.reverse }
            requestOUT(0xB0, 0, 0x2401, snr + [blockOffset, data.size / 4, 4].pack("CCC") + data)
            status, buf = requestIN(0xB0, 0, 0x2401)
            status == RFID::Status::OK
        end

        def resetRF
            requestIN(0x69, 0, 0, 3) == [RFID::Status::OK, ""]
        end

        def setRF(onoff)
            requestIN(0x6A, 0, onoff ? 1 : 0, 3) == [RFID::Status::OK, ""]
        end

        def close
            RFID::rfid_close(@rfid)
        end
    end
end

