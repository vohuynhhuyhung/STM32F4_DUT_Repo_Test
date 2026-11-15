*** Settings ***
# The Pico emulates a DS3231 real-time clock at 0x68 (simplified: the time registers run every second,
# no alarms / temperature / 12 h mode). The DUT uses its existing RTC driver and CLI commands:
#     rtc_init   rtc_set_time <h> <m> <s>   rtc_get_time   rtc_set_date <dow> <date> <mon> <yy>   rtc_get_date
# Time registers (BCD): 0x00 sec  0x01 min  0x02 hour  0x03 day 1..7  0x04 date  0x05 month  0x06 year
# Wiring: DUT SDA -> Pico GP0, DUT SCL -> Pico GP1. No other device at 0x68 on the bus.
# HIL_ROOT is injected by the CI runner.
Resource          ${HIL_ROOT}/HIL_robot/resources/HIL_keywords.robot
Resource          ${HIL_ROOT}/HIL_robot/user_resources/DUT_keywords.robot

Suite Setup       Run Keywords    Connect To HIL    AND    HIL Power DUT On
...               AND    Wait Until Keyword Succeeds    30s    2s    Connect To DUT
...               AND    Connect To Logic Analyzer
...               AND    Pico RTC Start    AND    DUT Init RTC
Suite Teardown    Run Keywords    Run Keyword And Ignore Error    Pico RTC Stop
...               AND    Disconnect from Logic Analyzer    AND    Disconnect from DUT    AND    Disconnect from HIL
Test Setup        Pico RTC Start    reset=True

*** Test Cases ***
DUT Sets The Time
    DUT Set RTC Time    hour=14    minute=30    second=45
    Pico RTC Time Should Be    2000-01-01 14:30:45    tolerance=2

DUT Sets The Date
    # BCD encoding done by the DUT driver: day 5, 13/11/26 -> registers 03..06 = 05 13 11 26
    DUT Set RTC Date    dow=5    date=13    month=11    year=26
    Pico I2C Register Should Be    0x03    0x05    0x13    0x11    0x26

DUT Reads The Time
    Pico RTC Set Time    2026-11-13 08:15:00    dow=5
    ${time}=    DUT Get RTC Time
    RTC Time Should Be Within    ${time}    8    15    0    tolerance=1

Clock Is Running
    Pico RTC Set Time    2026-11-13 12:00:00
    Sleep    3s
    ${time}=    DUT Get RTC Time
    RTC Time Should Be Within    ${time}    12    0    3    tolerance=1

New Year Rollover
    DUT Set RTC Date    dow=4    date=31    month=12    year=26
    DUT Set RTC Time    hour=23    minute=59    second=58
    Sleep    3s
    ${date}=    DUT Get RTC Date
    RTC Date Should Be    ${date}    dow=5    date=1    month=1    year=27
    ${time}=    DUT Get RTC Time
    RTC Time Should Be Within    ${time}    0    0    1    tolerance=2
