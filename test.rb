require 'pp'
require 'rfid'

RFID::Device.new(0) do |rfid|
    loop do 
        rfid.readSerials.each do |label|
            # Loeschen
            rfid.write(label.snr, "\x00" * 4 * 28)

            # Auslesen
            data, blocksRead, blockSize = rfid.read(label.snr, 0, 28)
            if data
                p data
                p data.size
            end
        end
    end
end
