#!/usr/bin/env ruby
require 'rfid'

text  = ARGV.join(' ')
text += "\x00" * (4 - text.size % 4)

RFID::Device.new(0) do |rfid|
    loop do 
        rfid.readSerials.each do |label|
            if rfid.write(label.snr, text) 
                puts "Wrote to #{label.snrHex}"
            end
        end
    end
end
