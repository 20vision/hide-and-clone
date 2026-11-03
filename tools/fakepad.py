#!/usr/bin/env python3
"""Virtual Xbox pad through /dev/uinput for testing native builds. Needs root. Reads lines from stdin: 'b <name>', 'a <axis> <val>', 'q'."""
import fcntl,os,struct,sys,time
EV_SYN,EV_KEY,EV_ABS=0,1,3
BTN={'A':0x130,'B':0x131,'X':0x133,'Y':0x134,'LB':0x136,'RB':0x137,'BACK':0x13a,'START':0x13b,'GUIDE':0x13c,'LS':0x13d,'RS':0x13e}
ABS={'LX':0,'LY':1,'LT':2,'RX':3,'RY':4,'RT':5,'HX':16,'HY':17}
UI_SET_EVBIT,UI_SET_KEYBIT,UI_SET_ABSBIT=0x40045564,0x40045565,0x40045567
UI_DEV_CREATE,UI_DEV_DESTROY=0x5501,0x5502
fd=os.open('/dev/uinput',os.O_WRONLY|os.O_NONBLOCK)
for e in (EV_KEY,EV_ABS,EV_SYN): fcntl.ioctl(fd,UI_SET_EVBIT,e)
for b in BTN.values(): fcntl.ioctl(fd,UI_SET_KEYBIT,b)
for a in ABS.values(): fcntl.ioctl(fd,UI_SET_ABSBIT,a)
amax=[0]*64;amin=[0]*64;fuzz=[0]*64;flat=[0]*64
for k,a in ABS.items():
    if k in('LX','LY','RX','RY'): amin[a],amax[a]=-32768,32767
    elif k in('LT','RT'): amin[a],amax[a]=0,1023
    else: amin[a],amax[a]=-1,1
name=b'Microsoft X-Box 360 pad'.ljust(80,b'\0')
dev=name+struct.pack('<HHHH',3,0x045e,0x028e,0x0114)+struct.pack('<I',0)+struct.pack('<64i',*amax)+struct.pack('<64i',*amin)+struct.pack('<64i',*fuzz)+struct.pack('<64i',*flat)
os.write(fd,dev);fcntl.ioctl(fd,UI_DEV_CREATE);time.sleep(.5)
def ev(t,c,v): os.write(fd,struct.pack('<qqHHi',0,0,t,c,v))
def syn(): ev(EV_SYN,0,0)
print('ready',flush=True)
for l in sys.stdin:
    p=l.split()
    if not p: continue
    if p[0]=='q': break
    if p[0]=='b':
        ev(EV_KEY,BTN[p[1]],1);syn();time.sleep(.14);ev(EV_KEY,BTN[p[1]],0);syn()
    if p[0]=='a':
        ev(EV_ABS,ABS[p[1]],int(p[2]));syn()
fcntl.ioctl(fd,UI_DEV_DESTROY);os.close(fd)
