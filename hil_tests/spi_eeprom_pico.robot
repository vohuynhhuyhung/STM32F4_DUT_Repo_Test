*** Settings  ***
# The Pico emulates a 25LC020A-style SPI EEPROM (simplified: 256 bytes, 16-byte pages), the DUT is the
# SPI3 master (mode 1). Instructions: 06 WREN, 05 RDSR (bit 0 WIP, bit 1 WEL), 03 READ <a>, 02 WRITE <a> <d..>.
# Like the real chip: WRITE without WREN is ignored, the address wraps inside the page, WIP = 1 for 5 ms.
# The DUT uses its EEPROM driver:   ee_wr <addr> <b1> [..b6]     ee_rd <addr> <len>
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
Test Setup        Pico SPI EEPROM Start    mode=${DUT_SPI_MODE}    erase=True

*** Variables ***
${DUT_SPI_MODE}    1

*** Test Cases ***
DUT Writes And Reads Back
    DUT SPI EEPROM Write    0x20    0x11    0x22    0x33    0x44
    Pico SPI EEPROM Should Contain    0x20    0x11    0x22    0x33    0x44
    ${data}=    DUT SPI EEPROM Read    0x20    length=4
    Lists Should Be Equal    ${data}    ${{[0x11, 0x22, 0x33, 0x44]}}

DUT Reads Preloaded Data
    Pico SPI EEPROM Set    0x40    0xDE    0xAD    0xBE    0xEF
    ${data}=    DUT SPI EEPROM Read    0x40    length=4
    Lists Should Be Equal    ${data}    ${{[0xDE, 0xAD, 0xBE, 0xEF]}}

Write Sequence On The Wire
    # driver: check ready (RDSR), WREN, check WEL (RDSR), WRITE, then poll RDSR until WIP = 0
    DUT SPI EEPROM Write    0x30    0x5A
    Pico SPI Should Receive Frames    05 00    06    05 00    02 30 5A    then_only=05 00
    Pico SPI EEPROM Should Contain    0x30    0x5A

Write Across A Page Boundary
    # 0x0D..0x12 crosses the page boundary at 0x10: the driver must split it into two WRITEs,
    # otherwise the chip wraps 0x10..0x12 back to 0x00..0x02
    DUT SPI EEPROM Write    0x0D    0xA1    0xA2    0xA3    0xA4    0xA5    0xA6
    Pico SPI EEPROM Should Contain    0x0D    0xA1    0xA2    0xA3    0xA4    0xA5    0xA6
    Pico SPI Should Contain Frame    mosi=02 10 A4 A5 A6

Write Without WREN Is Ignored
    # raw WRITE frame 02 50 AA sent with the generic spi_wr command (no WREN before it)
    DUT SPI Write Register    0x02    0x50    0xAA
    Pico SPI EEPROM Should Contain    0x50    0xFF
