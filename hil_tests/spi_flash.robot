*** Settings  ***
# HIL_ROOT is injected by the CI runner.
Resource    ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource    ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot

Suite Setup         Run Keywords    Connect To HIL    AND    HIL Power DUT On    AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
Suite Teardown      Run Keywords    Disconnect from DUT    AND    Disconnect from HIL

*** Variables ***
${LENGTH_512}    512

*** Test Cases ***
DUT Reads SPI Flash ID
    [Documentation]    HIL emulates a W25Q; the DUT must read back ID EF4018 over SPI.
    DUT Read SPI Flash ID

DUT Reads Data Prepared By HIL
    HIL prepare SPI Flash data    length=${LENGTH_512}
    ${data}=    DUT Read SPI Flash Data    length=${LENGTH_512}
    Data Should Increment    data=${data}
