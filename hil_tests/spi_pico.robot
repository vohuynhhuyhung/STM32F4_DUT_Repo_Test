*** Settings ***
# Documentation     DUT SPI3 master -> Pico (protocol analyzer + slave), no other slave on the bus.
# ...               The Pico captures every CS frame (MOSI and MISO) and answers on MISO with 0x00
# ...               (W25Q status 0x00 = "not busy", so the DUT flash driver never hangs).
# ...               Wiring: DUT PC10 (SCK) -> GP10, PC12 (MOSI) -> GP11, PC11 (MISO) -> GP12,
# ...               PD0 (CS) -> GP13. NOTE: the DUT J3 silkscreen swaps SCK/MOSI: use the PC pin names.
# ...               DUT SPI3 is mode 1 (CPOL 0, CPHA 1).
# HIL_ROOT is injected by the CI runner.
Resource          ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource          ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot
Library           Collections

Suite Setup       Run Keywords    Connect To HIL    AND    HIL Power DUT On
...               AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
...               AND    Connect To Logic Analyzer
...               AND    Pico SPI Slave Reply    0x00
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Pico SPI Slave Reply    off
...               AND    Run Keyword And Ignore Error    Pico SPI Disable
...               AND    Disconnect from Logic Analyzer    AND    Disconnect from DUT    AND    Disconnect from HIL
Test Setup        Pico SPI Enable    mode=${DUT_SPI_MODE}

*** Variables ***
${DUT_SPI_MODE}    1

*** Test Cases ***
Read ID Command On The Wire
    [Documentation]    w25q_ID = one CS frame, MOSI 9F 00 00 00. The Pico answers 00 on MISO,
    ...                so the DUT must report ID 0x0000.
    ${resp}=    DUT Execute Command    w25q_ID
    Pico SPI Should Contain Frame    mosi=9F 00 00 00    miso=00 00 00 00
    Should Contain    ${resp}    W25Q ID: 0x0000

DUT Receives What The Pico Answers
    [Documentation]    The Pico now answers 0xFF: the DUT must see exactly that on MISO.
    Pico SPI Slave Reply    0xFF
    ${resp}=    DUT Execute Command    w25q_ID
    Pico SPI Slave Reply    0x00
    Pico SPI Should Contain Frame    mosi=9F 00 00 00    miso=FF FF FF FF
    Should Contain    ${resp}    W25Q ID: 0xFFFFFFff

Page Program Sequence On The Wire
    [Documentation]    w25q_write 16 = Write Enable (06), Page Program (02 + 24-bit address 0 + data 00..0F),
    ...                then Read Status (05 FF) until "not busy".
    DUT Write SPI Flash Data    length=16
    ${data}=    Evaluate    " ".join(f"{i:02X}" for i in range(16))
    Pico SPI Should Receive Frames    06    02 00 00 00 ${data}    then_only=05 FF

Read Command On The Wire Matches DUT Data
    [Documentation]    w25q_read 16 = Read (03 + address 0 + 16 dummy FF). The bytes the DUT prints
    ...                must be exactly the MISO bytes on the wire (here 00, answered by the Pico).
    ${dut_data}=    DUT Read SPI Flash Data    length=16
    ${dummy}=    Evaluate    " ".join(["FF"] * 16)
    ${frame}=    Pico SPI Should Contain Frame    mosi=03 00 00 00 ${dummy}
    ${wire}=    Evaluate    [f"{b:02X}" for b in $frame["miso"][4:]]
    ${dut}=    Evaluate    [s.upper() for s in $dut_data]
    Lists Should Be Equal    ${wire}    ${dut}
