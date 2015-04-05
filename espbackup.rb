#!/usr/local/bin/ruby
#############################################################
# Create FAST ESP 360 Snapshot/Archive file for transfer.
#############################################################
require 'fileutils'
datestamp = Time.now
date = datestamp.strftime("%Y%m%d")
def dump_db
dbdump = `export 'LD_LIBRARY_PATH="/opt/fast/esp/bin/../lib"' & /opt/fast/esp/bin/cobra /opt/fast/esp/esp4j/bin/backupadminserver.py -m backup`
puts dbdump
puts "Completed DB backup."
end
def create_snapshot
createsnapshot = `/usr/bin/rsync -avr --exclude-from '/opt/apps/espbackup/etc/rsync/exclude.txt' /opt/apps/fast/ /opt/apps/espbackup/tmp/`
puts createsnapshot
end
def setup_env
setupenv = `source '/opt/fast/esp/bin/setupenv.sh'`
puts setupenv
end
def show_status
status = `export 'LD_LIBRARY_PATH="/opt/fast/esp/bin/../lib"' & /opt/fast/esp/bin/nctrl status | grep Adminserver | awk '{print $4}'`
puts status
end
def stop_service
stopservice = `export 'LD_LIBRARY_PATH="/opt/fast/esp/bin/../lib"' & /opt/fast/esp/bin/nctrl stop adminserver`
puts stopservice
end
def start_service
startservice = `export 'LD_LIBRARY_PATH="/opt/fast/esp/bin/../lib"' & /opt/fast/esp/bin/nctrl start adminserver`
puts startservice
end
# Required to stop logtransformer after backup.
def stop_logtransformer
stoplogtransformer = `export 'LD_LIBRARY_PATH="/opt/fast/esp/bin/../lib"' & /opt/fast/esp/bin/nctrl stop logtransformer`
puts stoplogtransformer
end
#############################################################
# set working environment
Dir.chdir('/opt/apps/fast/esp/bin')
setup_env
# Clean working directories.
Dir.chdir('/opt/apps/espbackup/tmp')
system "rm -rf /opt/apps/espbackup/tmp/*"
system "rm -rf /opt/apps/espbackup/tmp/.ssh"
system "rm -rf /opt/apps/espbackup/tmp/.flexlmrc"
system "rm -rf /opt/apps/espbackup/tmp/.bash_profile"
system "rm -rf /opt/apps/espbackup/tmp/.mysql_history"
puts "Cleaned tmp directory."
# Clean fast backup directory.
Dir.chdir('/opt/apps/espbackup/archive')
system "/bin/rm -rf /opt/apps/espbackup/archive/*"
puts "Cleaned archive directory."
# Clean adminserver db backup directory.
Dir.chdir('/opt/apps/fast/')
system "/bin/rm -rf /opt/apps/fast/adminserverbackup/*"
puts "Cleaned adminserverbackup directory"
# Stop Adminserver & Logtransformer, and Dump databases
Dir.chdir('/opt/apps/fast')
dump_db
# Setup environment and stop service.
Dir.chdir('/opt/apps/fast/esp/bin')
setup_env
#
case show_status
when 'Running'; then stop_service
when 'User suspended'; then puts "Adminserver is suspended."
when 'Dead'; then puts "Adminserver is dead."
when 'Stopping'; then puts "Adminserver is stopping."
else stop_service
end
# Fail safe.
if show_status == 'Running'
puts "Stopping the Adminserver before creating snapshot."
stop_service
end
# Take snapshot.
create_snapshot
# Start service.
start_service
# Stop logtransformer
stop_logtransformer
# Create archive file.
system "/bin/tar -C /opt/fast -cf /opt/apps/espbackup/archive/fast . "
# Add hostname to archive file.
Dir.chdir('/opt/apps/espbackup/archive')
# Clean working directory after use.
Dir.chdir('/opt/apps/espbackup/tmp')
system "/bin/rm -rf /opt/apps/espbackup/tmp/*"
system "rm -rf /opt/apps/espbackup/tmp/.ssh"
system "rm -rf /opt/apps/espbackup/tmp/.flexlmrc"
system "rm -rf /opt/apps/espbackup/tmp/.bash_profile"
system "rm -rf /opt/apps/espbackup/tmp/.mysql_history"
# Add extension to filename.
Dir.chdir('/opt/apps/espbackup/archive')
Dir.glob("*").each do |file|
File.new(file, "r").gets
newfile = file + "-" + "bcp-admin" + "-" + date + ".tar"
File.rename(file, newfile)
end
# Compress file.
system "/bin/gzip /opt/apps/espbackup/archive/fast*.tar"
