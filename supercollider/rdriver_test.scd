SerialPort.listDevices
a = ArduinoGRBL("/dev/tty.usbserial-A94JRL5D", 115200);

r = RoverDriver(a, NetAddr("localhost", 12345)