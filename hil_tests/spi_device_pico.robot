*** Settings ***
# The Pico emulates a small SPI sensor with 16 registers, the DUT is the SPI3 master (mode 1).
# Frame: first byte = R/W bit (bit 7, 1 = read) + register address, then data (auto-increment).
# The DUT talks to it like to a real device with its generic commands:
#     spi_wr <reg> <b1> [..b6]     spi_rd <reg> <len>
# Emulated register map used here:
#     0x00 WHO_AM_I = 0xA5   0x01 CTRL   0x02..0x03 DATA (MSB, LSB)   0x04..0x06 scratch
# Wiring (no other slave on the bus): DUT PC10 (SCK) -> GP10, PC12 (MOSI) -> GP11,
# PC11 (MISO) -> GP12, PD0 (CS) -> GP13. The DUT J3 silkscreen swaps SCK/MOSI: use the PC pin names.
# HIL_ROOT is injected by the CI runner.
Resource          ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource          ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot
Library           Collections

Suite Setup       Run Keywords    Connect To HIL    AND    HIL Power DUT On
...               AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
...               AND    Connect To Logic Analyzer
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Pico SPI Device Stop
...               AND    Disconnect from Logic Analyzer    AND    Disconnect from DUT    AND    Disconnect from HIL
Test Setup        Start Emulated SPI Sensor

*** Variables ***
${DUT_SPI_MODE}    1
${WHO_AM_I}        0xA5

*** Test Cases ***
DUT Reads Device ID
    ${id}=    DUT SPI Read Register    0x00
    Should Be Equal As Integers    ${id}[0]    ${WHO_AM_I}

Read Command On The Wire
    [Documentation]    Reading register 0 = MOSI 80 00 (read bit + address, then a dummy byte);
    ...                the device answers the ID in the second byte.
    DUT SPI Read Register    0x00
    Pico SPI Should Contain Frame    mosi=80 00    miso=?? A5

DUT Configures The Device
    DUT SPI Write Register    0x01    0x81
    Pico SPI Register Should Be    0x01    0x81
    Pico SPI Should Contain Frame    mosi=01 81

DUT Reads Live Sensor Data
    [Documentation]    The test changes the measurement registers; the DUT must read the new values each time.
    Pico SPI Set Register    0x02    0x12    0x34
    ${data}=    DUT SPI Read Register    0x02    length=2
    Lists Should Be Equal    ${data}    ${{[0x12, 0x34]}}
    Pico SPI Set Register    0x02    0xAB    0xCD
    ${data}=    DUT SPI Read Register    0x02    length=2
    Lists Should Be Equal    ${data}    ${{[0xAB, 0xCD]}}

DUT Burst Writes Consecutive Registers
    DUT SPI Write Register    0x04    0x11    0x22    0x33
    Pico SPI Register Should Be    0x04    0x11    0x22    0x33

DUT Burst Reads The Whole Map
    [Documentation]    16-byte read with auto-increment: the device must keep up with the clock.
    ${expected}=    Evaluate    [0x10 + i for i in range(16)]
    Pico SPI Set Register    0x00    @{expected}
    ${data}=    DUT SPI Read Register    0x00    length=16
    Lists Should Be Equal    ${data}    ${expected}

*** Keywords ***
Start Emulated SPI Sensor
    Pico SPI Device Start    mode=${DUT_SPI_MODE}    reset=True
    Pico SPI Set Register    0x00    ${WHO_AM_I}
