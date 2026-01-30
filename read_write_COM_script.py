import serial

# Cấu hình cổng COM
COM_PORT = 'COM17'
BAUD_RATE = 115200  # thay đổi theo thiết bị của bạn
TIMEOUT = 1  # timeout đọc, giây

# Đọc toàn bộ dữ liệu từ file image.raw
with open('video.mp4', 'rb') as f:
    image_data = f.read()

# Mở cổng COM
ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=TIMEOUT)

try:
    # Mở file output.raw để ghi dữ liệu nhận được
    with open('output.mp4', 'wb') as out_file:
        # Gửi dữ liệu ra COM
        ser.reset_input_buffer()
        ser.write(image_data)
        

        while True:
            data = ser.read(1024)
            if data:
                out_file.write(data)
                out_file.flush()
                print(f"Received {len(data)} bytes")
            else:
                # Không còn dữ liệu – có thể tăng timeout hoặc break thủ công
                pass

finally:
    ser.close()
    print("COM port đã đóng.")
