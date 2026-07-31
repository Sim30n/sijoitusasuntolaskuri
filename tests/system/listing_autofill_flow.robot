*** Settings ***
Documentation     System tests for the listing-autofill UI's client-side/config-error paths.
...               These deliberately avoid calling the real Anthropic API (no network access,
...               no API key needed, deterministic) - the request/response contract with Claude
...               is covered offline in tests/integration/listing_extractor_contract.robot.
...               A live end-to-end check (real URL, real API key) exists separately as an
...               opt-in manual check - see tests/README.md "Live API checks".
Resource          ../resources/streamlit_app.resource
Suite Setup       Start Streamlit App
Suite Teardown    Stop Streamlit App
Test Setup        Open App Page
Test Teardown      Close App Page

*** Test Cases ***
Fetching Listing Without A Url Or File Shows A Warning
    Click    text="Hae tiedot ilmoituksesta"
    Wait Until Keyword Succeeds    10x    0.5s    Alert Should Contain    Anna ensin ilmoituksen linkki tai lataa tiedosto.

Fetching Listing With A Url But No Api Key Shows A Configuration Error
    [Documentation]    The app under test runs without ANTHROPIC_API_KEY set (see Start Streamlit
    ...                App), so this exercises the real error path listing_extractor.py takes
    ...                when the key is missing, surfaced through the actual UI.
    Fill Text    css=input[aria-label="Ilmoituksen linkki"]    https://example.com/ilmoitus/123
    Click    text="Hae tiedot ilmoituksesta"
    Wait Until Keyword Succeeds    10x    0.5s
    ...    Alert Should Contain    ANTHROPIC_API_KEY-ympäristömuuttujaa ei ole asetettu.

*** Keywords ***
Alert Should Contain
    [Arguments]    ${expected_text}
    ${alerts}=    Get Alert Texts
    ${joined}=    Evaluate    " | ".join($alerts)
    Should Contain    ${joined}    ${expected_text}
