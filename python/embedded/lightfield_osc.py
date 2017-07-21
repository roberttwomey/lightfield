#! /usr/bin/python
 

""" 

turning raspicam on and off with OSC commands
 
rtwomey@uw.edu 2014

"""

import socket
import OSC
import os
import datetime
import time, threading
from subprocess import call

 
 
# ==== CAMERA SECTION ==== #
def getImagePath():  # new
    return datetime.datetime.now().strftime("/home/pi/lfimages/%Y-%m-%d_%H.%M.%S")
    
# ==== OSC SECTION ==== #

# tupple with ip the OSC server will listen to. 
receive_address = '192.168.42.1', 9000
 
# OSC Server. there are three different types of server.
server = OSC.OSCServer(receive_address) # basic
##s = OSC.ThreadingOSCServer(receive_address) # threading
##s = OSC.ForkingOSCServer(receive_address) # forking

# this registers a 'default' handler (for unmatched messages),
# an /'error' handler, an '/info' handler.
# And, if the client supports it, a '/subscribe' & '/unsubscribe' handler
server.addDefaultHandlers()
     
stopped = False
fastCamStarted = False

def start_camd():
    outpath = getImagePath()
    if not os.path.exists(outpath):
        os.makedirs(outpath)
    
    call(['/home/pi/code/raspifastcamd/start_camd.sh', os.path.join(outpath, "image%04d.jpg")])
    return True
    
# define a message-handler function for the server to call.
def printing_handler(addr, tags, data, source):
    global stopped, fastCamStarted
    
    # print "---"
    # print "received from :  %s" % OSC.getUrlStr(source)
    # print "with addr : %s" % addr
    # print "typetags : %s" % tags
    # print "data : %s" % data
    # print "---"

    if data[0] == 'start':
        print "received start"
        start_camd()
        fastCamStarted = True

    elif data[0] == 'stop':
        print "received stop"

    elif data[0] == 'snap':
        print "received snap"

        if not fastCamStarted:
            start_camd()
            fastCamStarted = True

        # take photo
        call(['/home/pi/code/raspifastcamd/do_capture.sh'])

        print "snapped"
  
    elif data[0] == 'exit':
        print "received exit"
        stopped = True

    elif data[0] == 'paramsnap':
        print "paramsnap"
        call(['/usr/bin/raspistill'] + data[1].split(" "))

# add callback to handle address
server.addMsgHandler("/camera", printing_handler) # adding our function, first parameter corresponds to the OSC address you want to listen to
    
          
# just checking which handlers we have added
print "Registered Callback-functions are :"
for addr in server.getOSCAddressSpace():
    print addr
     
      
# Start OSCServer
print "\nStarting OSCServer. Use ctrl-C to quit."
st = threading.Thread( target = server.serve_forever )
st.start()

     
try :
    while 1 :
        time.sleep(5)
        print "zzz..."
        if stopped == True:
            print "stopped"
            break
        
except KeyboardInterrupt :
    print "closing"
    
# exiting
print "Exiting\n"

if fastCamStarted:
    print "\nQuitting camd"
    call(['/home/pi/code/raspifastcamd/stop_camd.sh'])
    
print "\nClosing OSCServer."
server.close()
print "Waiting for Server-thread to finish"
st.join() ##!!!
print "Done"
