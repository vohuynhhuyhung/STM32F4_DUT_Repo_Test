*** Settings ***
# The Pico emulates a small I2C sensor (GP0=SDA, GP1=SCL) with 16 registers behind an 8-bit pointer.
# The DUT talks to it like to a real device with its generic commands:
#     i2c_wr <addr> <reg> <b1> [..b5]     i2c_rd <addr> <reg> <len>
# Emulated register map used here:
#     0x00 WHO_AM_I = 0x5A   0x01 CTRL   0x02..0x03 DATA (MSB, LSB)   0x04..0x06 scratch
# HIL_ROOT is injected by the CI runner.
Resource          ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource          ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot
Library           Collections

Suite Setup       Run Keywords    Connect To HIL    AND    HIL Power DUT On
...               AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
...               AND    Connect To Logic Analyzer
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Pico I2C Slave Disable
...               AND    Disconnect from Logic Analyzer    AND    Disconnect from DUT    AND    Disconnect from HIL
Test Setup        Start Emulated Sensor

*** Variables ***
${SENSOR_ADDR}     0x68
${WHO_AM_I}        0x5A

*** Test Cases ***
DUT Reads Device ID
    ${id}=    DUT I2C Read Register    ${SENSOR_ADDR}    0x00
    Should Be Equal As Integers    ${id}[0]    ${WHO_AM_I}

DUT Configures The Device
    DUT I2C Write Register    ${SENSOR_ADDR}    0x01    0x81
    Pico I2C Register Should Be    0x01    0x81

DUT Reads Live Sensor Data
    [Documentation]    The test changes the measurement registers; the DUT must read the new values each time.
    Pico I2C Set Register    0x02    0x12    0x34
    ${data}=    DUT I2C Read Register    ${SENSOR_ADDR}    0x02    length=2
    Lists Should Be Equal    ${data}    ${{[0x12, 0x34]}}
    Pico I2C Set Register    0x02    0xAB    0xCD
    ${data}=    DUT I2C Read Register    ${SENSOR_ADDR}    0x02    length=2
    Lists Should Be Equal    ${data}    ${{[0xAB, 0xCD]}}

DUT Burst Writes Consecutive Registers
    DUT I2C Write Register    ${SENSOR_ADDR}    0x04    0x11    0x22    0x33
    Pico I2C Register Should Be    0x04    0x11    0x22    0x33

Wrong Address Is Not Acknowledged
    DUT I2C Read Should Fail    0x69

*** Keywords ***
Start Emulated Sensor
    Pico I2C Device Start    addr=${SENSOR_ADDR}    reset=True
    Pico I2C Set Register    0x00    ${WHO_AM_I}
