#!/usr/bin/env python3
import socket, sys, json

cmd = sys.argv[1] if len(sys.argv) > 1 else '{}'
s = socket.socket(socket.AF_UNIX)
s.connect('/tmp/app-launcher.sock')
s.send(cmd.encode())
data = b''
while True:
    chunk = s.recv(65536)
    if not chunk:
        break
    data += chunk
s.close()
print(data.decode())
