#!/usr/bin/env ruby
require 'rfid'

RFID::Device.new(0) do |rfid|
    loop do 
        rfid.readSerials.each do |label|
            data, blocksRead, blockSize = rfid.read(label.snr, 0, 28)
            puts "Read from #{label.snrHex}: #{data}" if data
        end
    end
end
