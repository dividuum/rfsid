#!/usr/bin/env ruby
require 'rfid'
require 'pp'

RFID::Device.new(0) do |rfid|
    puts "eeprom"
    1.upto(7) do |cfg|
        buf = rfid.readConfig(cfg, true)
        next unless buf
        print "CFG%d " % cfg
        buf.each do |b|
            print "%02x " % b
        end
        puts
    end

    puts "ram"
    1.upto(7) do |cfg|
        buf = rfid.readConfig(cfg, false)
        next unless buf
        print "CFG%d " % cfg
        buf.each do |b|
            print "%02x " % b
        end
        puts
    end
end
