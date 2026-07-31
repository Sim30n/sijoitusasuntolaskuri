*** Settings ***
Documentation     Shared keywords for driving a real, locally-launched instance of my_app.py
...               through a browser. Used by every suite under tests/system/.
Library           Process
Library           Browser
Library           Collections
Library           ../libraries/AppServerLibrary.py


*** Variables ***
# Path to a Chromium binary the Browser library (Playwright) should launch.
# Leave empty to let Playwright use whatever browser `rfbrowser init` downloaded.
# The sandbox this suite was authored in has Playwright's browsers pre-installed
# outside the usual cache location, so CI/dev machines should override this via
# the CHROMIUM_EXECUTABLE_PATH environment variable if they hit the same setup.
${CHROMIUM_EXECUTABLE_PATH}    %{CHROMIUM_EXECUTABLE_PATH=/opt/pw-browsers/chromium-1194/chrome-linux/chrome}
${REPO_ROOT}      ${CURDIR}/../..


*** Keywords ***
Start Streamlit App
    [Documentation]    Launches `streamlit run my_app.py` on a free port and waits until it's healthy.
    ${port}=    Get Free Port
    Set Suite Variable    ${APP_URL}    http://127.0.0.1:${port}
    Start Process
    ...    streamlit    run    my_app.py
    ...    --server.port\=${port}    --server.headless\=true    --server.address\=127.0.0.1
    ...    cwd=${REPO_ROOT}
    ...    alias=streamlit_app
    ...    stdout=${OUTPUT_DIR}/streamlit_stdout.log
    ...    stderr=${OUTPUT_DIR}/streamlit_stderr.log
    ...    env:ANTHROPIC_API_KEY=${EMPTY}
    Wait For Health    ${APP_URL}/_stcore/health    timeout=40

Stop Streamlit App
    [Documentation]    Terminates the Streamlit process started by `Start Streamlit App`.
    Terminate Process    streamlit_app    kill=True

Open App Page
    [Documentation]    Opens a fresh browser page pointed at the running app and waits for it to render.
    New Browser    browser=chromium    headless=True    executablePath=${CHROMIUM_EXECUTABLE_PATH}
    New Context    viewport={'width': 1440, 'height': 1200}
    New Page    ${APP_URL}
    Wait For Elements State    css=input[aria-label="Vuokra (€/kk)"]    visible    timeout=20s
    Wait For Elements State    css=[data-testid="stDataFrame"]    visible    timeout=20s

Close App Page
    Close Browser

Set Number Input
    [Documentation]    Replaces the value of a Streamlit number_input/slider identified by its aria-label.
    [Arguments]    ${label}    ${value}
    ${selector}=    Set Variable    css=input[aria-label="${label}"]
    Focus    ${selector}
    Press Keys    ${selector}    Control+a
    Press Keys    ${selector}    Delete
    Type Text    ${selector}    ${value}
    Press Keys    ${selector}    Tab

Get Number Input Value
    [Arguments]    ${label}
    ${value}=    Get Attribute    css=input[aria-label="${label}"]    value
    RETURN    ${value}

Get Metric Text
    [Documentation]    Returns the full text of the first st.metric widget whose label starts with ${label_prefix}.
    [Arguments]    ${label_prefix}
    ${metrics}=    Get Elements    css=[data-testid="stMetric"]
    FOR    ${metric}    IN    @{metrics}
        ${text}=    Get Text    ${metric}
        ${matches}=    Evaluate    """${text}""".startswith("""${label_prefix}""")
        IF    ${matches}
            RETURN    ${text}
        END
    END
    Fail    No st.metric found with label prefix '${label_prefix}'

Get Alert Texts
    [Documentation]    Returns the text of every st.alert (info/warning/error) box currently on the page.
    ${alerts}=    Get Elements    css=[data-testid="stAlert"]
    ${texts}=    Create List
    FOR    ${alert}    IN    @{alerts}
        ${text}=    Get Text    ${alert}
        Append To List    ${texts}    ${text}
    END
    RETURN    ${texts}

Parse Euro Amount
    [Documentation]    Extracts the euro amount from an st.metric's full text, e.g. turns
    ...                "Kokonaisvoitto (28.07.2031)\n\n18,086 e" (e = euro sign) into 18086.0.
    [Arguments]    ${text}
    ${number}=    Evaluate    finance_test_helpers.parse_euro_amount("""${text}""")    modules=finance_test_helpers
    RETURN    ${number}
