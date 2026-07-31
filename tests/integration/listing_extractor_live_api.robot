*** Settings ***
Documentation     OPT-IN live-API check: calls the real Anthropic API through listing_extractor.py.
...               NOT run by default (tag: live-api) - it costs real API usage, needs network
...               egress, and depends on Claude successfully handling a request. It intentionally
...               does not assert on specific extracted values (the target URL is not a real
...               listing) - only that the real API round-trip returns a well-formed result
...               without raising. The request/response contract itself (schema, error mapping)
...               is covered deterministically and offline in listing_extractor_contract.robot.
...
...               Run explicitly with:
...                 ANTHROPIC_API_KEY=sk-ant-... robot --include live-api tests/integration/listing_extractor_live_api.robot
Library           OperatingSystem
Library           Collections
Library           ../../listing_extractor.py

*** Test Cases ***
Extract From A Url Returns A Well Formed Result
    [Tags]    live-api
    ${key}=    Get Environment Variable    ANTHROPIC_API_KEY    default=${EMPTY}
    Skip If    '${key}' == '${EMPTY}'    ANTHROPIC_API_KEY not set - skipping live API check
    ${result}=    Extract From Url    https://example.com/
    Dictionary Should Contain Key    ${result}    purchase_price
    Dictionary Should Contain Key    ${result}    monthly_rent
    Dictionary Should Contain Key    ${result}    housing_fee
    Dictionary Should Contain Key    ${result}    notes
