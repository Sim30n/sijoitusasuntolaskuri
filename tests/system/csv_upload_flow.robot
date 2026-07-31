*** Settings ***
Documentation     System test for CSV batch mode: uploading a CSV of candidate apartments through
...               the real file uploader must prefill the manual-entry form with the most
...               profitable listing, exactly as tests/integration/csv_batch_pipeline.robot
...               verifies at the function level - this suite checks the browser-visible result.
Resource          ../resources/streamlit_app.resource
Suite Setup       Start Streamlit App
Suite Teardown    Stop Streamlit App
Test Setup        Open App Page
Test Teardown      Close App Page

*** Variables ***
${DATA_DIR}       ${CURDIR}/../data

*** Test Cases ***
Uploading Csv Prefills The Form With The Most Profitable Listing
    [Documentation]    valid_listings.csv row 1 (50000e price, 900e rent, 80e fee) is deliberately
    ...                the standout candidate - see tests/integration/csv_batch_pipeline.robot.
    Upload File By Selector    css=[data-testid="stFileUploaderDropzoneInput"][accept*="csv"]    ${DATA_DIR}/valid_listings.csv
    Wait Until Keyword Succeeds    10x    0.5s    Vuokra Field Should Not Be Default

    ${vuokra}=    Get Number Input Value    Vuokra (€/kk)
    Should Be Equal As Numbers    ${vuokra}    900

    ${yhtiovastike}=    Get Number Input Value    Yhtiövastike (€/kk)
    Should Be Equal As Numbers    ${yhtiovastike}    80

Uploading A Single Row Csv Prefills The Only Candidate
    Upload File By Selector    css=[data-testid="stFileUploaderDropzoneInput"][accept*="csv"]    ${DATA_DIR}/single_listing.csv
    Wait Until Keyword Succeeds    10x    0.5s    Vuokra Field Should Not Be Default

    ${vuokra}=    Get Number Input Value    Vuokra (€/kk)
    Should Be Equal As Numbers    ${vuokra}    550
    ${yhtiovastike}=    Get Number Input Value    Yhtiövastike (€/kk)
    Should Be Equal As Numbers    ${yhtiovastike}    120

*** Keywords ***
Vuokra Field Should Not Be Default
    ${vuokra}=    Get Number Input Value    Vuokra (€/kk)
    Should Not Be Equal As Numbers    ${vuokra}    460
