#!/usr/bin/ruby
require 'yaml'

max = 6
time = 3
count = 0

# inventory-cron.rb is to be run with first boot script
#     on first boot this script ensures that the computer is in inventory
# AND on the regular cron trigger 
#     this script ensures inventory hw specs is up-to-date

host_ip   = '-i -k https://inventory.las.ch'
#host_ip   = '-i -k https://10.164.64.57'
#host_ip   = '-i --url http://10.164.64.57'
#host_ip    = '-i --url http://127.0.0.1:4567'
#host_ip    = '-i http://127.0.0.1:4567'

auth = YAML::load_file("auth.yml")
usrname = auth['usrname']
passwd  = auth['passwd']

#puts "usrname: #{usrname}, passwd: #{passwd}"
#puts

results_hash = {
  "macid0"     => `ifconfig en0 | grep ether   | cut -dr -f2`.strip                                                            ,
  "serial"     => `system_profiler SPHardwareDataType | grep 'Serial Number (system):'| cut -d':' -f2 | cut -d' ' -f2`.strip   ,
  "ws_name"    => `system_profiler SPSoftwareDataType | grep 'Computer Name:' | cut -d':' -f2 | cut -d' ' -f2`.strip           , 
  "ws_model"   => `system_profiler SPHardwareDataType | grep 'Model Identifier:' |cut -d':' -f2 | cut -d' ' -f2`.strip         , 
  "cpu_speed"  => `system_profiler SPHardwareDataType | grep 'Processor Speed:' |cut -d':' -f2 | cut -d' ' -f2-9`.strip        ,
  "cpu_name"   => `system_profiler SPHardwareDataType | grep 'Processor Name:' |cut -d':' -f2 | cut -d' ' -f2-9`.strip         ,
  "ram"        => `system_profiler SPHardwareDataType | grep 'Memory:' | grep GB | cut -d':' -f2 | cut -d' ' -f2,3`.strip      ,
  "os_version" => `system_profiler SPSoftwareDataType | grep 'System Version:' | cut -d':' -f2 | cut -d' ' -f2-5`.strip        ,
  "en0_ip"     => `ifconfig en0 | grep netmask | cut -dt -f2 | cut -dn -f1`.strip                                              ,
  "en1_mac"    => `ifconfig en1 | grep ether   | cut -dr -f2`.strip                                                            ,
  "en1_ip"     => `ifconfig en1 | grep netmask | cut -dt -f2 | cut -dn -f1`.strip                                              ,
  "last_user"  => `last -1 | cut -d" " -f1`.strip                                                                              ,
  "backup_hd"  => `system_profiler | grep 'My Passport' -A 10 | grep 'Serial Number:' | cut -d':' -f2 | cut -d' ' -f2-5`.strip 
}

# always update the hardware profile
f = File.new("db-hw-update.sh", "w")
   f.print "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X PUT"
   results_hash.each { |key, value|  f.print " -d #{key}=\"#{value}\"" } 
   f.puts     
f.close  

test_user = results_hash.fetch("last_user")

if File::exists?("imageversion.txt")
   f = File.open("imageversion.txt")
   f.each do |line|
     results_hash["image_vers"] = line.chomp
   end
   f.close
end

# is this the first run?
if !(File::exists?("first_run.txt"))
   results_hash["last_user"] = "first-boot"
   results_hash["status"] = "Ready"
   results_hash["issued_to"] = ""

   f = File.new("db-hw-create.sh", "w")
      f.print "curl #{host_ip}/computers -u #{usrname}:#{passwd} -X POST"
      results_hash.each { |key, value|  f.print " -d #{key}=\"#{value}\"" }
      f.puts
   f.close

   f = File.new("db-hw-update.sh", "w")
      f.print "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X PUT"
      results_hash.each { |key, value|  f.print " -d #{key}=\"#{value}\"" } 
      f.puts     
   f.close  
   
   #system( File.read("db-hw-delete.sh").strip )   
   #system( File.read("db-hw-create.sh").strip )
   # test that the create or update works after a few tries
   # See if the record is already created
   create = ''   
   update = ''  
   while not ( (create.include? "HTTP/1.1 201 Created") || (update.include? "HTTP/1.1 202 Accepted") || (count >= max) )
      create = `bash db-hw-create.sh`
      # try an update - if a create didn't work -- maybe the machine already exists
      update = `bash db-hw-update.sh` if !( (create.include? "HTTP/1.1 201 Created") || (update.include? "HTTP/1.1 202 Accepted") )
      sleep time.to_i
      count += 1
   end
   if count < max   # if an update or creation succeeded then note it.
      f = File.new("first_run.txt", "w")
         f.puts "#{results_hash.fetch("last_user")} -- " + Time.now.to_s
      f.close
      
      f = File.new("db-hw-return.sh", "w")
         f.puts "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X PUT -d issued_to=\"IT\" -d status=\"instock\" "
      f.close

      f = File.new("db-hw-delete.sh", "w")
         f.puts "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X DELETE "
      f.close

      f = File.new("reset-testing.sh", "w")
         f.puts "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X DELETE "
         f.puts "rm first*.txt"
         f.puts "rm issued*"
         f.puts "rm last*"
         f.puts "rm db-*.sh"
      f.close
   else
      f = File.new("last-failure.txt", "a")
          f.puts "FAILED -- " + Time.now.to_s
      f.close	     
   end   
   #puts "no first_run.txt file"
   #exec("cat db-hw-create.sh")
   #puts create
   #puts update

# is the current user IT Admin or if it isn't logged in
elsif ( (test_user.downcase == "first-boot") || (test_user.downcase == "itadmin") || (test_user.downcase == "test") || (test_user.downcase == "root") || (test_user.downcase == "reboot") || (test_user.downcase == "shutdown") || (test_user.downcase == "wtmp") || (test_user.downcase == "it") || (test_user.downcase == "system") )
    f = File.new("last-it-login.txt", "a")
        f.puts "#{test_user} -- " + Time.now.to_s
    f.close
    # update even if not loged in - in case it is stolen , etc.
    system( File.read("db-hw-update.sh").strip )
      
# is this the first normal USER login - then issue the computer to the current user
elsif !( File::exists?("first_user.txt") )     
      
   results_hash["issued_to"] = results_hash.fetch("last_user")
   results_hash["last_user"] = "first-login"
   results_hash["issued_on"] = Time.now.to_s    
   results_hash["status"] = "Deployed"  
	    
   f = File.new("db-issued-to.sh", "w")
       f.print "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X PUT"
       results_hash.each { |key, value|  f.print " -d #{key}=\"#{value}\"" } 
       f.puts     
   f.close  
     
   #system( File.read("db-issued-to.sh").strip )
   issued = ''
   while not ( (issued.include? "HTTP/1.1 202 Accepted") || (count >= max) )
      issued = `bash db-issued-to.sh`
      count += 1
      sleep time.to_i
   end
   if count < max   # if an update or creation succeeded then note it.
  	  f = File.new("first_user.txt", "w")
		      f.puts "#{results_hash.fetch("issued_to")}"
      f.close  
	    f = File.new("first_login.txt", "w")
		      f.puts "#{results_hash.fetch("issued_to")} -- " + Time.now.to_s
      f.close  
      f = File.new("last-user.txt", "a")
          f.puts "#{results_hash.fetch("last_user")} -- " + Time.now.to_s
      f.close
      system( File.read("AfterIssued.sh").strip )
  else 
      f = File.new("last-failure.txt", "a")
          f.puts "FAILED -- " + Time.now.to_s
      f.close	
  end 
  #puts "no first_user.txt file -- issued to setup"
  #exec("cat db-issued-to.sh")
  #puts issued

# Is this a normal update while a normal user is logged in?
elsif ( File::exists?("first_user.txt") )     
    results_hash["status"] = "Deployed"
    # Get the issued_to use from the first_user file - just to be safe update this
    f = File.open("first_user.txt")
       f.each do |line|
          results_hash["issued_to"] = line.chomp
       end
    f.close

    f = File.new("db-last-user.sh", "w")
       f.print "curl #{host_ip}/computers/#{results_hash.fetch("macid0")} -u #{usrname}:#{passwd} -X PUT"
       results_hash.each { |key, value|  f.print " -d #{key}=\"#{value}\"" } 
       f.puts     
    f.close
    
    #system( File.read("db-last-user.sh").strip )  
    update = ''
    while not ( (update.include? "HTTP/1.1 202 Accepted") || (count >= max) )
       update = `bash db-last-user.sh`
       count += 1
       sleep time.to_i
    end
    if count < max   # if an update or creation succeeded then note it.
       f = File.new("last-user.txt", "a")
           f.puts "#{results_hash.fetch("last_user")} -- " + Time.now.to_s
       f.close
	  else 
	     f = File.new("last-failure.txt", "a")
           f.puts "FAILED -- " + Time.now.to_s
       f.close	
	  end
    #puts "normal user update"
    #exec("cat db-last-user.sh")
    
end
# any other condition - maybe on and no one logged on -- just checkin with the inventory server
#else   
#    system( File.read("db-hw-update.sh").strip )
#end
  
