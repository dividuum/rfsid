#!/usr/bin/env ruby
require 'rfid'
require 'pp'

RFID::Device.new(0) do |rfid|
    1.upto(7) do |cfg|
        rfid.resetConfig(cfg, false)
        rfid.resetConfig(cfg, true)
    end
    rfid.resetCPU
end
