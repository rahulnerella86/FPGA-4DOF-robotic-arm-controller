import serial
import json
import argparse

def save_calibration(data, filename="calibration.json"):
    with open(filename, 'w') as f:
        json.dump(data, f, indent=4)
    print(f"Calibration saved to {filename}")

def load_calibration(filename="calibration.json"):
    try:
        with open(filename, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return {str(i): {"min": 50000, "max": 100000, "center": 75000} for i in range(4)}

def calibrate():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=str, default="COM3")
    args = parser.parse_args()
    
    try:
        ser = serial.Serial(args.port, 115200)
    except Exception as e:
        print(f"Could not open port: {e}")
        return

    cal_data = load_calibration()

    def send_pulse(servo_id, pulse):
        ph = (pulse >> 8) & 0xFF
        pl = pulse & 0xFF
        chk = 0x01 ^ servo_id ^ ph ^ pl
        ser.write(bytearray([0xAA, 0x01, servo_id, ph, pl, chk, 0x55]))

    print("Interactive Servo Calibration")
    print("Commands: '+' to increase, '-' to decrease, 'save' to commit, 'next' to move to next state/servo, 'quit' to exit.")

    for servo in range(4):
        print(f"\nCalibrating Servo {servo}")
        for state in ["min", "center", "max"]:
            pulse = cal_data[str(servo)][state]
            print(f"Setting {state} position. Current pulse: {pulse}")
            send_pulse(servo, pulse)
            
            while True:
                cmd = input(f"Servo {servo} {state}> ").strip()
                if cmd == '+':
                    pulse += 1000
                elif cmd == '-':
                    pulse -= 1000
                elif cmd == 'next':
                    cal_data[str(servo)][state] = pulse
                    break
                elif cmd == 'save':
                    cal_data[str(servo)][state] = pulse
                    save_calibration(cal_data)
                elif cmd == 'quit':
                    ser.close()
                    return
                else:
                    try:
                        pulse = int(cmd)
                    except:
                        pass
                
                send_pulse(servo, pulse)
                print(f"Pulse: {pulse} ({pulse/50000.0} ms)")

    save_calibration(cal_data)
    ser.close()

if __name__ == "__main__":
    calibrate()
