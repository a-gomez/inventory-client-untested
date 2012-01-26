#!/usr/bin/ruby
#2011-09-15

require 'rubygems'
require 'net/http'
require 'net/https'
require 'highline/import'
#sudo gem install highline

http = Net::HTTP.new("inventory.las.ch",443)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

return_user = "unknown"
#return_prog = "SIS"
return_prog = "LAS"
#return_prog = "EMP"

usrname = ask("Enter username:  ") { |x| x.echo = true }
puts 
puts "Please enter the PASSWORD:"
passwd  = ''
while ( passwd ==  '' || passwd == ' ' )
   puts "blanks are not acceptable "
   #passwd = Password.get( "password: " )
   passwd = ask("Enter password:  ") { |x| x.echo = "" }
   #passwd = ask("Enter password:  ") { |x| x.echo = "*" }
end

comp_hash = {
    # "macid0"     => `ifconfig en0 | grep ether   | cut -dr -f2`.strip                                                            ,
    # "serial"     => `system_profiler SPHardwareDataType | grep 'Serial Number (system):'| cut -d':' -f2 | cut -d' ' -f2`.strip   ,
    # "ws_name"    => `system_profiler SPSoftwareDataType | grep 'Computer Name:' | cut -d':' -f2 | cut -d' ' -f2`.strip           ,
    # "ws_model"   => `system_profiler SPHardwareDataType | grep 'Model Identifier:' |cut -d':' -f2 | cut -d' ' -f2`.strip         , 
    # "cpu_speed"  => `system_profiler SPHardwareDataType | grep 'Processor Speed:' |cut -d':' -f2 | cut -d' ' -f2-9`.strip        ,
    # "cpu_name"   => `system_profiler SPHardwareDataType | grep 'Processor Name:' |cut -d':' -f2 | cut -d' ' -f2-9`.strip         ,
    # "ram"        => `system_profiler SPHardwareDataType | grep 'Memory:' | grep GB | cut -d':' -f2 | cut -d' ' -f2,3`.strip      ,
    # "os_version" => `system_profiler SPSoftwareDataType | grep 'System Version:' | cut -d':' -f2 | cut -d' ' -f2-5`.strip        ,
    # "en0_ip"     => `ifconfig en0 | grep netmask | cut -dt -f2 | cut -dn -f1`.strip                                              ,
    # "en1_mac"    => `ifconfig en1 | grep ether   | cut -dr -f2`.strip                                                            ,
    # "en1_ip"     => `ifconfig en1 | grep netmask | cut -dt -f2 | cut -dn -f1`.strip                                              ,
    # "last_user"  => `last -1 | cut -d" " -f1`.strip                                                                              ,
    # "backup_hd"  => `system_profiler | grep 'My Passport' -A 10 | grep 'Serial Number:' | cut -d':' -f2 | cut -d' ' -f2-5`.strip 

    "macid0"     => `ifconfig en0 | grep ether   | cut -dr -f2`.strip                                                          ,
    "serial"     => `system_profiler SPHardwareDataType | grep 'Serial Number (system):'| cut -d':' -f2 | cut -d' ' -f2`.strip ,
    "os_version" => `system_profiler SPSoftwareDataType | grep 'System Version:' | cut -d':' -f2 | cut -d' ' -f2-5`.strip      ,
}

if ARGV.length==0 then  
  comp_hash["return_reason"] = "#{return_prog} -- #{return_user}"
else
  comp_hash["return_reason"] = ARGV[0]
end

cur_name = `system_profiler SPSoftwareDataType | grep 'Computer Name:' | cut -d':' -f2 | cut -d' ' -f2`.strip 
comp_hash["ws_name"] = "inv-#{cur_name}"
comp_hash["status"] = "returned"
comp_hash["comp_condition"] = "good"
comp_hash["assigned_ip"] = ""
comp_hash["issued_to"] = "it-inventory"
comp_hash["issue_grp"] = "it-storage"
comp_hash["sleeve"] = "n-a"
comp_hash["powersupply"] = "n-a"
comp_hash["backup_hd"] = "n-a"
comp_hash["polyvision"] = "n-a"
comp_hash["dongle"] = "n-a"

# RESTful update
request  = Net::HTTP::Put.new("/computers/#{comp_hash.fetch("macid0")}")
request.set_form_data( comp_hash )
request.basic_auth("#{usrname}","#{passwd}")
response = http.request(request)
response_code = response.code
#puts response_code
puts
if response_code == "202"
  puts "UPDATE SUCCESS" 
elsif response_code == "403"
  puts "WRONG PASSWORD - please run again"
else
  puts "UPDATE FAILED - Please report the below info for debugging."
  puts "       http-error: #{response_code} for mac-id: #{comp_hash.fetch("macid0")}"
end
puts
