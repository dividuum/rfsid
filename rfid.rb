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
        OK                      = 0x00
        NO_TRANSPONDER          = 0x01
        DATA_FALSE              = 0x02
        WRITE_ERROR             = 0x03
        ADDRESS_ERROR           = 0x04
        WRONG_TRANSPONDER_TYPE  = 0x05
        EEPROM_FAILURE          = 0x10
        PARAMETER_RANGE_ERROR   = 0x11
        UNKNOWN_COMMAND         = 0x80
        LENGTH_ERROR            = 0x81
        COMMAND_NOT_AVAILABLE   = 0x82
        RF_COMMUNICATION_ERROR  = 0x83
        MORE_DATA               = 0x94
        ISO_15693_ERROR         = 0x95
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
            case status 
            when RFID::Status::OK
                info = OpenStruct.new
                info.softwareRevision = "%02x-%02x" % [buf[0], buf[1]]
                info.hardwareType     = buf[3]
                info.firmware         = buf[4]
                info.firmwareName     = case info.firmware
                                        when 0x48: "ID ISC.PRH100-A"
                                        when 0x49: "ID ISC.MR100-U"
                                        when 0x4A: "ID ISCMR/PR100-A"
                                        else       "unknown"
                                        end
                info.transponder      = [buf[5], buf[6]]                                    
                info
            else
                nil
            end
        end

        def readSerials
            serials  = []
            moredata = false
            begin
                status, buf = requestIN(0xB0, 0, moredata ? 0x0180 : 0x0100)
                case status
                when RFID::Status::MORE_DATA, RFID::Status::OK:
                    numserials = buf[0]
                    buf.slice!(0)
                    raise "size inconsistency" unless buf.size == numserials * 10
                    numserials.times do |i|
                        serial = OpenStruct.new
                        serial.trType     = buf[0]
                        serial.trTypeName = case buf[0]
                                            when 0x00: "Philips I-CODE1"
                                            when 0x01: "Texas Instruments Tag-it HF"
                                            when 0x03: "ISO15693 Tags"
                                            else       "unknown"
                                            end
                        serial.blockSize  = case buf[0]
                                            when 0x00: 4
                                            when 0x01: 4
                                            when 0x03: 8
                                            end
                        serial.dsfid      = buf[1]
                        serial.snr        = buf[2..9]
                        serial.snrHex     = buf[2..9].unpack("H*")[0]
                        serials << serial
                        buf.slice!(0..9)
                    end
                    moredata = status == RFID::Status::MORE_DATA
                    puts "FSDFSDFSFD" if moredata
                when RFID::Status::NO_TRANSPONDER:
                else
                    raise "cannot read serials" 
                end
            end while moredata
            serials
        end

        def read(snr, blockOffset = 0, blockCount = 1)
            raise "invalid address" unless snr.size == 8
            requestOUT(0xB0, 0, 0x2301, snr + [blockOffset, blockCount].pack("CC"))
            status, buf = requestIN(0xB0, 0, 0x2301)
            case status
            when RFID::Status::OK:
                # <numBlocksRead> <blockSize> {0 data3 data2 data1 data0}*
                raise "cannot read data" unless status == RFID::Status::OK
                raise "reply too small"  unless buf.size >= 2
                numBlocks = buf[0]
                blockSize = buf[1]
                buf.slice!(0..1)
                raise "block size inconsistency"  unless buf.size == numBlocks * (blockSize + 1)
                data = ""
                numBlocks.times do 
                    data << buf[1..blockSize].reverse
                    buf.slice!(0..blockSize)
                end
                [data, numBlocks, blockSize]
            when RFID::Status::NO_TRANSPONDER:
                nil
            else
                warn "unknown status #{status}"
                nil
            end
        end

        def write(snr, data, blockOffset = 0, blockSize = 4)
            # FIXME: Support fuer Blocksize != 4 einbauen?
            return false unless data.size % blockSize == 0
            data.gsub!(/#{'.' * blockSize}/m) { |b| b.reverse }
            requestOUT(0xB0, 0, 0x2401, snr + [blockOffset, data.size / blockSize, blockSize].pack("CCC") + data)
            requestIN(0xB0, 0, 0x2401) == [RFID::Status::OK, ""]
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
