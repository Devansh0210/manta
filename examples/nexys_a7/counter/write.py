import serial
from time import sleep

with serial.Serial("/dev/tty.usbserial-210292AE39A41", 115200) as ser:
    for i in range(8):
        req = '{:04X}'.format(i)
        req = f"M{req}1234\r\n  "
        req = req.encode('ascii')

        ser.write(req)
        print(f"req --> {req}")
        sleep(0.1)