#!/usr/bin/env ruby
require 'rfid'
require 'pp'

RFID::Device.new(0) do |rfid|
    1.upto(7) do |cfg|
        buf = rfid.readConfig(cfg)
        next unless buf
        print "CFG%d " % cfg
        buf.each do |b|
            print "%02x " % b
        end
        puts
    end
end
