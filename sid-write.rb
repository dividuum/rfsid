#!/usr/bin/env ruby
require 'rfid'
require 'zlib'

files = []
if ARGV.empty?
    $stdin.each_line do |line|
        files << line[9..-1].chomp
    end
else
    files = ARGV
end

$stdout.sync  = true
writtenlabels = []

RFID::Device.new(0) do |rfid|
    until files.empty? do 
        puts "Scanning..."
        rfid.readSerials.each do |label|
            # Nur Infinieon Labels mit 1000byte Speicher
            next unless label.trType    == 3 
            next unless label.blockSize == 8 
            next if writtenlabels.include?(label)

            sidfile = files.first
            siddata = Zlib::Deflate.deflate(File.open(sidfile).read)
            data    = [siddata.size + 2, siddata].pack("n a*")

            puts "data size: #{data.size}"

            if data.size > 1000
                puts "too large"
                exit
            end
            
            print "Writing #{sidfile}: #{data.size} bytes to #{label.snrHex}"

            # Labels sind erst ab Block 3 schreibbar
            offset     = 3
            labeldata  = data.dup
            begin
                block = labeldata.slice!(0..127)
                block = block + "\x00" * (8 - block.size % 8) if block.size != 128
                if rfid.write(label.snr, block, offset, 8) 
                    print "."
                else 
                    print "?"
                    break
                end
                offset += 16
            end until labeldata.empty?
            
            if labeldata.empty?
                puts "OK"
                files.shift
                writtenlabels << label
            else
                puts "Failed"
            end
        end
    end
end
