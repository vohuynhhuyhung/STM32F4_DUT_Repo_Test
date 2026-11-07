*** Settings ***
# HIL_ROOT and FIRMWARE_PATH are injected by the CI runner.
Resource    ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource    ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot

Suite Setup         Run Keywords    Connect To HIL    AND    HIL Power DUT On    AND    Connect To DUT
Suite Teardown      Run Keywords    Disconnect from DUT    AND    Disconnect from HIL

*** Test Cases ***
DUT Firmware Boots And Answers CLI
    [Documentation]    After flashing, the DUT console must answer "help".
    Verify DUT Alive

DUT Lists Expected Commands
    ${help}=    DUT Help
    Should Contain    ${help}    w25q_ID
    Should Contain    ${help}    i2c_scan
    Should Contain    ${help}    rtc_get_time
