*** Settings ***
Documentation     Integration tests for listing_extractor.py: verifies how it talks to the
...                Anthropic SDK (request shape, response parsing, error mapping) with the
...                `anthropic.Anthropic` client stubbed out - so these run offline and
...                deterministically, but still exercise the real extract_from_url/
...                extract_from_file code paths end to end. Live-API smoke checks live in
...                listing_extractor_live_api.robot (tag: live-api, excluded by default).
Library           ../libraries/ListingExtractorTestLibrary.py
Test Teardown     Restore Environment

*** Test Cases ***
Extract From Url Returns The Fields Claude Produced
    Set Anthropic Api Key
    Stub Anthropic Success    payload=${{{'purchase_price': 65000, 'monthly_rent': 500, 'housing_fee': 120, 'notes': None}}}
    ${result}=    Extract From Url    https://example.com/ilmoitus/123
    Should Be Equal As Numbers    ${result}[purchase_price]    65000
    Should Be Equal As Numbers    ${result}[monthly_rent]    500
    Should Be Equal As Numbers    ${result}[housing_fee]    120

Extract From Url Uses The Web Fetch Tool
    [Documentation]    extract_from_url must hand Claude the web_fetch tool so it can read the page itself.
    Set Anthropic Api Key
    Stub Anthropic Success    payload=${{{'purchase_price': None, 'monthly_rent': None, 'housing_fee': None, 'notes': None}}}
    Extract From Url    https://example.com/ilmoitus/123
    ${used_web_fetch}=    Get Last Request Used Web Fetch Tool
    Should Be True    ${used_web_fetch}

Missing Fields Are Returned As Null Rather Than Guessed
    Set Anthropic Api Key
    Stub Anthropic Success    payload=${{{'purchase_price': 65000, 'monthly_rent': None, 'housing_fee': None, 'notes': 'Vuokraa ei mainittu.'}}}
    ${result}=    Extract From Url    https://example.com/ilmoitus/123
    Should Be Equal As Numbers    ${result}[purchase_price]    65000
    Should Be Equal    ${result}[monthly_rent]    ${NONE}
    Should Be Equal    ${result}[housing_fee]    ${NONE}

Missing Api Key Raises A Finnish Language Error Before Calling The Api
    Unset Anthropic Api Key
    Run Keyword And Expect Error
    ...    ListingExtractionError: ANTHROPIC_API_KEY-ympäristömuuttujaa ei ole asetettu.
    ...    Extract From Url    https://example.com/ilmoitus/123

Model Refusal Raises A Listing Extraction Error
    Set Anthropic Api Key
    Stub Anthropic Refusal
    Run Keyword And Expect Error
    ...    ListingExtractionError: Claude ei pystynyt käsittelemään pyyntöä.
    ...    Extract From Url    https://example.com/ilmoitus/123

Empty Response Content Raises A Listing Extraction Error
    Set Anthropic Api Key
    Stub Anthropic Empty Response
    Run Keyword And Expect Error
    ...    ListingExtractionError: Claudelta ei saatu jäsenneltyä vastausta.
    ...    Extract From Url    https://example.com/ilmoitus/123

Api Status Error Is Wrapped As A Listing Extraction Error
    Set Anthropic Api Key
    Stub Anthropic Status Error    message=rate limited
    Run Keyword And Expect Error
    ...    ListingExtractionError: Claude API -virhe: rate limited
    ...    Extract From Url    https://example.com/ilmoitus/123

Api Connection Error Is Wrapped As A Listing Extraction Error
    Set Anthropic Api Key
    Stub Anthropic Connection Error
    Run Keyword And Expect Error
    ...    ListingExtractionError: Yhteys Claude API:iin epäonnistui.
    ...    Extract From Url    https://example.com/ilmoitus/123

Extract From File Handles A Pdf Upload
    Set Anthropic Api Key
    Stub Anthropic Success    payload=${{{'purchase_price': 70000, 'monthly_rent': 550, 'housing_fee': 130, 'notes': None}}}
    ${result}=    Extract From File    ${CURDIR}/../data/single_listing.csv    application/pdf
    Should Be Equal As Numbers    ${result}[purchase_price]    70000

Extract From File Rejects An Unsupported Mime Type Before Calling The Api
    Set Anthropic Api Key
    Stub Anthropic Success    payload=${{{'purchase_price': None, 'monthly_rent': None, 'housing_fee': None, 'notes': None}}}
    Run Keyword And Expect Error
    ...    ListingExtractionError: Tiedostotyyppiä ei tueta. Lataa PDF- tai kuvatiedosto (PNG/JPEG/WebP).
    ...    Extract From File    ${CURDIR}/../data/single_listing.csv    text/csv
