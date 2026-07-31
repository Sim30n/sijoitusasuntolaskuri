*** Settings ***
Documentation     System smoke test: launches the real `streamlit run my_app.py` process and
...                drives it in an actual (headless) browser, verifying the golden path renders:
...                default form values produce a results table, two charts, and three summary
...                metrics with no errors on the page.
Resource          ../resources/streamlit_app.resource
Suite Setup       Start Streamlit App
Suite Teardown    Stop Streamlit App
Test Setup        Open App Page
Test Teardown      Close App Page

*** Test Cases ***
Application Loads With Default Values And Renders Results
    Get Text    css=body    contains    Kiinteistön tiedot
    Get Text    css=body    contains    Laina
    Get Text    css=body    contains    Vuokraus
    Get Text    css=body    contains    Myynti
    Get Text    css=body    contains    Yhteenveto

    ${table_count}=    Get Element Count    css=[data-testid="stDataFrame"]
    Should Be Equal As Integers    ${table_count}    1

    ${chart_count}=    Get Element Count    css=[data-testid="stVegaLiteChart"]
    Should Be Equal As Integers    ${chart_count}    2

    ${metric_count}=    Get Element Count    css=[data-testid="stMetric"]
    Should Be Equal As Integers    ${metric_count}    3

    ${alerts}=    Get Alert Texts
    Should Be Empty    ${alerts}

Summary Metrics Show Plausible Values For The Default Scenario
    ${first_positive}=    Get Metric Text    Ensimmäinen positiivinen kuukausi
    Should Match Regexp    ${first_positive}    (\\d{2}\\.\\d{2}\\.\\d{4}|Ei löytynyt)

    ${roe_text}=    Get Metric Text    ROE
    Should Match Regexp    ${roe_text}    -?\\d+([.,]\\d+)?\\s*%
