require 'rfid'

RFID::Device.new(0) do |rfid|
    loop do 
        rfid.readSerials.each do |label|
            data, blocksRead, blockSize = rfid.read(label.snr, 0, 28)
            if data
                puts "Read from #{label.snrHex}: #{data}"
            end
        end
    end
end
