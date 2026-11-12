*** Settings ***
# Documentation     DUT I2C3 master -> Pico I2C slave (GP0=SDA, GP1=SCL).
# ...               The Pico ACKs address 0x42 and logs every byte it receives.
# ...               DUT command: i2c_tx <len> [start] sends start, start+1, ... to 0x42.
# HIL_ROOT is injected by the CI runner.
Resource          ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource          ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot

Suite Setup       Run Keywords    Connect To HIL    AND    HIL Power DUT On
...               AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
...               AND    Connect To Logic Analyzer
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Pico I2C Slave Disable
...               AND    Disconnect from Logic Analyzer    AND    Disconnect from DUT    AND    Disconnect from HIL
Test Setup        Pico I2C Slave Enable    addr=${PICO_I2C_ADDR}

*** Variables ***
${PICO_I2C_ADDR}    0x42

*** Test Cases ***
DUT Sends 8 Bytes To Pico Slave
    DUT I2C Transmit Test Bytes    length=8
    Pico I2C Should Receive    00 01 02 03 04 05 06 07

DUT Sends Bytes Starting At Offset
    DUT I2C Transmit Test Bytes    length=4    start=0x10
    Pico I2C Should Receive    10 11 12 13

DUT Sends Maximum Length
    DUT I2C Transmit Test Bytes    length=64    start=0xC0
    ${expected}=    Evaluate    " ".join(f"{(0xC0 + i) & 0xFF:02X}" for i in range(64))
    Pico I2C Should Receive    ${expected}

DUT Gets NACK When Pico Slave Is Disabled
    Pico I2C Slave Disable
    DUT I2C Transmit Should Be NACKed
