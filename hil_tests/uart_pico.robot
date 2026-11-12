*** Settings ***
Documentation     DUT USART1 TX -> Pico UART receiver (GP21, protocol analyzer).
...               The Pico receives every byte the DUT sends, with line errors (framing, parity,
...               break, overrun). DUT commands: uart_tx <text>, uart_dump (bytes 00..FF), 115200 8N1.
# HIL_ROOT is injected by the CI runner.
Resource          ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource          ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot

Suite Setup       Run Keywords    Connect To HIL    AND    HIL Power DUT On
...               AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
...               AND    Connect To Logic Analyzer
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Pico UART Disable
...               AND    Disconnect from Logic Analyzer    AND    Disconnect from DUT    AND    Disconnect from HIL
Test Setup        Pico UART Enable    baud=${DUT_UART_BAUD}

*** Variables ***
${DUT_UART_BAUD}    115200
${TEXT}             Hello Pico from DUT

*** Test Cases ***
DUT Sends Text To Pico
    DUT Send UART String    ${TEXT}
    Pico UART Should Receive Text    ${TEXT}

DUT Sends All Byte Values
    DUT Send UART 256 Bytes
    ${expected}=    Evaluate    " ".join(f"{i:02X}" for i in range(256))
    Pico UART Should Receive Bytes    ${expected}

Pico Detects Wrong Baud Rate
    [Documentation]    Negative test: listening at 9600 baud must NOT look like a valid reception.
    Pico UART Enable    baud=9600
    DUT Send UART String    ${TEXT}
    Run Keyword And Expect Error    *UART*    Pico UART Should Receive Text    ${TEXT}
