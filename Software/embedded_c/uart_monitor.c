#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#define PACKET_SIZE 11
#define START_BYTE 0xAA
#define END_BYTE 0x55

typedef enum {
    WAIT_HEADER,
    READ_DATA,
    VALIDATE
} State;

State current_state = WAIT_HEADER;
uint8_t buffer[PACKET_SIZE];
uint8_t buf_index = 0;

void process_packet(uint8_t* packet) {
    uint8_t checksum = 0;
    for (int i = 1; i < 9; i++) {
        checksum ^= packet[i];
    }
    
    if (checksum != packet[9]) {
        printf("Checksum error!\n");
        return;
    }
    
    uint16_t s1 = (packet[1] << 8) | packet[2];
    uint16_t s2 = (packet[3] << 8) | packet[4];
    uint16_t s3 = (packet[5] << 8) | packet[6];
    uint16_t s4 = (packet[7] << 8) | packet[8];
    
    printf("S1: %u, S2: %u, S3: %u, S4: %u\n", s1, s2, s3, s4);
}

void uart_receive_byte(uint8_t b) {
    switch (current_state) {
        case WAIT_HEADER:
            if (b == START_BYTE) {
                buffer[0] = b;
                buf_index = 1;
                current_state = READ_DATA;
            }
            break;
        case READ_DATA:
            buffer[buf_index++] = b;
            if (buf_index == PACKET_SIZE - 1) {
                current_state = VALIDATE;
            }
            break;
        case VALIDATE:
            if (b == END_BYTE) {
                buffer[buf_index] = b;
                process_packet(buffer);
            }
            current_state = WAIT_HEADER;
            break;
    }
}

int main() {
    // Example test data representing a valid packet
    // 0xAA, S1_H, S1_L, S2_H, S2_L, S3_H, S3_L, S4_H, S4_L, CHK, 0x55
    uint8_t test_data[] = {0xAA, 0x12, 0x34, 0x56, 0x78, 0x12, 0x34, 0x56, 0x78, 0x00, 0x55};
    
    // Calculate valid checksum for test data
    test_data[9] = test_data[1] ^ test_data[2] ^ test_data[3] ^ test_data[4] ^ 
                   test_data[5] ^ test_data[6] ^ test_data[7] ^ test_data[8];

    for (int i = 0; i < sizeof(test_data); i++) {
        uart_receive_byte(test_data[i]);
    }

    return 0;
}
