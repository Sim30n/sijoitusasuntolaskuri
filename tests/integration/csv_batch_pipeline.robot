*** Settings ***
Documentation     Integration tests for the CSV batch-mode pipeline in my_app.py: real file I/O
...                (pandas CSV parsing) feeding into FinanceCalculator, and the "pick the most
...                profitable listing" step used to prefill the form. Unlike the unit suites,
...                these exercise analyze_csv_file()/get_df_with_highest_kokonaisvoitto() together
...                against real fixture files under tests/data/.
Library           ../libraries/FinanceCalculatorLibrary.py
Library           Collections

*** Variables ***
${DATA_DIR}       ${CURDIR}/../data

*** Test Cases ***
Analyze Csv File Returns One Result Per Listing Row
    ${results}=    Analyze Csv    ${DATA_DIR}/valid_listings.csv
    Length Should Be    ${results}    3

Single Row Csv Is Analyzed Without Error
    ${results}=    Analyze Csv    ${DATA_DIR}/single_listing.csv
    Length Should Be    ${results}    1
    ${records}=    Get From List    ${results}    0
    Should Not Be Empty    ${records}

Most Profitable Listing Is Selected From Multiple Candidates
    [Documentation]    valid_listings.csv row 1 (50000e, 900e rent, 80e fee) is deliberately far more
    ...                profitable than the other two rows, so it must be the one that wins.
    ${best}=    Highest Kokonaisvoitto Row    ${DATA_DIR}/valid_listings.csv    years_ahead=5
    Should Be Equal As Numbers    ${best}[myyntihinta]    50000
    Should Be Equal As Numbers    ${best}[yhtiövastike]    -80

Highest Kokonaisvoitto Row Is Also Consistent For A Single Candidate
    ${best}=    Highest Kokonaisvoitto Row    ${DATA_DIR}/single_listing.csv    years_ahead=5
    Should Be Equal As Numbers    ${best}[myyntihinta]    60000

Csv Missing A Required Column Fails Fast With A Clear Error
    [Documentation]    KNOWN GAP: analyze_csv_file assumes hinta/vuokra/yhtiövastike are all present
    ...                and raises a raw pandas KeyError with no user-facing message if one is missing.
    ...                This test pins down today's behavior so a future fix is a deliberate change,
    ...                not an accidental regression. See tests/README.md "Known gaps".
    [Tags]    known-issue
    Run Keyword And Expect Error    KeyError: *    Analyze Csv    ${DATA_DIR}/missing_column.csv
