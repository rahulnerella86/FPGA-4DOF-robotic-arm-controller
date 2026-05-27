import serial
import argparse
import time

class RoboticArmController:
    def __init__(self, port, baud=115200):
        try:
            self.ser = serial.Serial(port, baud, timeout=1)
            print(f"Connected to {port} at {baud} baud.")
        except serial.SerialException as e:
            print(f"Failed to connect to {port}: {e}")
            self.ser = None

    def send_packet(self, cmd_type, servo_id, pulse_width):
        if not self.ser:
            return
        
        pos_high = (pulse_width >> 8) & 0xFF
        pos_low = pulse_width & 0xFF
        checksum = cmd_type ^ servo_id ^ pos_high ^ pos_low
        
        packet = bytearray([0xAA, cmd_type, servo_id, pos_high, pos_low, checksum, 0x55])
        self.ser.write(packet)

    def angle_to_pulse(self, angle):
        # 0 to 180 degrees -> 50000 to 100000
        angle = max(0, min(180, angle))
        return int(50000 + (angle / 180.0) * 50000)

    def move(self, servo_id, angle):
        pulse = self.angle_to_pulse(angle)
        self.send_packet(0x01, servo_id, pulse)
        print(f"Moving servo {servo_id} to {angle} degrees (pulse: {pulse})")

    def home(self):
        self.send_packet(0x02, 0, 75000)
        print("Moving to home position.")

    def stop(self):
        self.send_packet(0x03, 0, 0)
        print("Emergency stop activated.")

    def close(self):
        if self.ser:
            self.ser.close()

def main():
    parser = argparse.ArgumentParser(description="4DOF Robotic Arm Controller")
    parser.add_argument("--port", type=str, default="COM3", help="Serial port")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate")
    args = parser.parse_args()

    controller = RoboticArmController(args.port, args.baud)
    if not controller.ser:
        return

    while True:
        try:
            cmd = input("Command (move <id> <angle>, home, stop, quit): ").strip().split()
            if not cmd:
                continue
            
            if cmd[0] == "quit":
                break
            elif cmd[0] == "home":
                controller.home()
            elif cmd[0] == "stop":
                controller.stop()
            elif cmd[0] == "move" and len(cmd) == 3:
                controller.move(int(cmd[1]), int(cmd[2]))
            else:
                print("Invalid command.")
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"Error: {e}")

    controller.close()

if __name__ == "__main__":
    main()
