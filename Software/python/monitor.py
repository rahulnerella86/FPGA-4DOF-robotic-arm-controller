import serial
import time
import argparse

def monitor(port, baud):
    try:
        ser = serial.Serial(port, baud, timeout=1)
    except Exception as e:
        print(f"Failed to connect: {e}")
        return

    print("Listening for telemetry... Press Ctrl+C to stop.")
    
    while True:
        try:
            if ser.in_waiting >= 11:
                if ser.read(1)[0] == 0xAA:
                    data = ser.read(10)
                    if data[9] == 0x55:
                        s1 = (data[0] << 8) | data[1]
                        s2 = (data[2] << 8) | data[3]
                        s3 = (data[4] << 8) | data[5]
                        s4 = (data[6] << 8) | data[7]
                        status = data[8]
                        
                        # Print clear screen escape sequence (ANSI)
                        print("\033[2J\033[H")
                        print("==== 4DOF Robotic Arm Telemetry ====")
                        print(f"Servo 1 (Base):    {s1} pulse")
                        print(f"Servo 2 (Elbow):   {s2} pulse")
                        print(f"Servo 3 (Wrist):   {s3} pulse")
                        print(f"Servo 4 (Gripper): {s4} pulse")
                        print(f"Status Byte:       0x{status:02X}")
                        print("====================================")
                        time.sleep(0.1)
        except KeyboardInterrupt:
            break
        except Exception as e:
            pass

    ser.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=str, default="COM3")
    parser.add_argument("--baud", type=int, default=115200)
    args = parser.parse_args()
    monitor(args.port, args.baud)
