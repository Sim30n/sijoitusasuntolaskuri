*** Settings ***
Documentation     System tests for the manual entry golden path: changing a form field must
...               reactively update the results table and summary metrics, end to end through
...               the real Streamlit app in a real browser (not just the calculation functions).
Resource          ../resources/streamlit_app.resource
Suite Setup       Start Streamlit App
Suite Teardown    Stop Streamlit App
Test Setup        Open App Page
Test Teardown      Close App Page

*** Test Cases ***
Increasing Rent Increases The Roe Shown In The Summary
    ${roe_before_text}=    Get Metric Text    ROE
    ${roe_before}=    Evaluate    finance_test_helpers.parse_percent("""${roe_before_text}""")    modules=finance_test_helpers

    Set Number Input    Vuokra (€/kk)    900
    Wait Until Keyword Succeeds    10x    0.5s    Roe Metric Should Differ From    ${roe_before_text}

    ${roe_after_text}=    Get Metric Text    ROE
    ${roe_after}=    Evaluate    finance_test_helpers.parse_percent("""${roe_after_text}""")    modules=finance_test_helpers
    Should Be True    ${roe_after} > ${roe_before}

Increasing Sale Price Increases Total Profit At The Investment Horizon
    ${profit_before_text}=    Get Metric Text    Kokonaisvoitto
    ${profit_before}=    Parse Euro Amount    ${profit_before_text}

    Set Number Input    Arvioitu myyntihinta laina-ajan lopussa (€)    120000
    Wait Until Keyword Succeeds    10x    0.5s    Kokonaisvoitto Metric Should Differ From    ${profit_before_text}

    ${profit_after_text}=    Get Metric Text    Kokonaisvoitto
    ${profit_after}=    Parse Euro Amount    ${profit_after_text}
    Should Be True    ${profit_after} > ${profit_before}

Increasing Own Equity Decreases The Roe Percentage
    [Documentation]    kokonaisvoitto (numerator) does not depend on oma_pääoma/capital, only the ROE
    ...                denominator does - so raising capital alone must strictly lower ROE %.
    ${roe_before_text}=    Get Metric Text    ROE
    ${roe_before}=    Evaluate    finance_test_helpers.parse_percent("""${roe_before_text}""")    modules=finance_test_helpers

    Set Number Input    Oma pääoma (€)    20000
    Wait Until Keyword Succeeds    10x    0.5s    Roe Metric Should Differ From    ${roe_before_text}

    ${roe_after_text}=    Get Metric Text    ROE
    ${roe_after}=    Evaluate    finance_test_helpers.parse_percent("""${roe_after_text}""")    modules=finance_test_helpers
    Should Be True    ${roe_after} < ${roe_before}

*** Keywords ***
Roe Metric Should Differ From
    [Arguments]    ${previous_text}
    ${current_text}=    Get Metric Text    ROE
    Should Not Be Equal As Strings    ${current_text}    ${previous_text}

Kokonaisvoitto Metric Should Differ From
    [Arguments]    ${previous_text}
    ${current_text}=    Get Metric Text    Kokonaisvoitto
    Should Not Be Equal As Strings    ${current_text}    ${previous_text}
