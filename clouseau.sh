# What files is it touching?
sudo opensnoop-bpfcc -p $(pgrep -f "claude") 

# Network connections
sudo tcpconnect-bpfcc -p $(pgrep -f "claude")

# Any subprocesses it spawns
sudo execsnoop-bpfcc
