# Testing strategy

Robot Framework test suite for sijoitusasuntolaskuri, split into the classic three layers:
**unit**, **integration**, and **system**. All three run as Robot Framework suites; the
difference between them is what's real and what's replaced at each layer, not the tool.

```
tests/
  unit/           pure calculation logic, no I/O, no browser, no app process
  integration/    multiple internal collaborators wired together (file I/O + pandas +
                  calculator; the Anthropic SDK contract with a stubbed client)
  system/         the real `streamlit run my_app.py` process, driven through a real
                  headless browser
  libraries/      Python keyword libraries / test doubles the .robot suites import
  resources/      shared Robot keywords (app lifecycle, form helpers) for system tests
  data/           CSV fixtures shared by integration and system suites
  results/        Robot's output.xml/log.html/report.html (gitignored, regenerated per run)
```

## Why Robot Framework for unit tests too

Robot Framework isn't a unit-testing framework by default, but `my_app.py`'s calculation
core (`FinanceCalculator`) is plain, stateless Python with no Streamlit dependency at call
time. `tests/libraries/FinanceCalculatorLibrary.py` is a thin keyword-library adapter around
it: it calls `FinanceCalculator` directly and hands back plain dicts/lists so `.robot` suites
can assert on them with `Should Be Equal As Numbers` etc. Values run in-process (no Remote
library, no serialization), so Python types pass through unchanged.

## Running the tests

```bash
pip install -r requirements.txt -r tests/requirements-test.txt
rfbrowser init            # one-time: wires up the Playwright driver Browser library uses

tests/run_tests.sh              # unit + integration + system (excludes the opt-in live-API check)
tests/run_tests.sh unit         # fast, no browser, no app process — run this on every change
tests/run_tests.sh integration  # still no browser; excludes live-api
tests/run_tests.sh system       # launches the real app + a headless Chromium
tests/run_tests.sh live-api     # opt-in, needs ANTHROPIC_API_KEY + network — see below
```

Results land in `tests/results/` (`report.html` / `log.html` per run).

### Browser setup note

System tests use `robotframework-browser` (Playwright-based). If your machine already has a
Playwright Chromium install outside the default cache path — as the sandbox this suite was
authored in does, at `/opt/pw-browsers/...` — point `CHROMIUM_EXECUTABLE_PATH` at the `chrome`
binary before running:

```bash
export CHROMIUM_EXECUTABLE_PATH=/path/to/chrome-linux/chrome
```

Otherwise, a plain `rfbrowser init` (without `--skip-browsers`) downloads Playwright's own
Chromium and no override is needed.

## Layer 1 — Unit tests (`tests/unit/`)

Target: `FinanceCalculator.calculate_annuity_loan_payments` and `FinanceCalculator.calculate_data`,
tested **separately** from each other via `tests/libraries/FinanceCalculatorLibrary.py`:

- `annuity_loan_payments.robot` — the amortization formula. Cross-checked against
  hand-computed reference values (independent application of the standard annuity-payment
  formula, not a re-run of the app's own code), plus invariants: schedule length matches loan
  term, principal is fully repaid by the last month, interest/fee sign conventions, and the
  `int(round(loan_term_years))` rounding behavior for fractional years.
- `investment_data_calculations.robot` — the rent/tax/sale math, using
  `Build Monthly Loan Records` to construct a synthetic loan schedule so these tests exercise
  `calculate_data`'s own rules (monthly income formula, cumulative profit, ROE, the
  divide-by-zero-equity NaN case, the date-range filter) independently of the annuity formula.
  Also pins down an easy-to-miss asymmetry: `loan_cost` is front-loaded over the first 12 rows,
  while `maintenance_cost` is spread flat across every row of the investment horizon, forever.

No Streamlit, no network, no file I/O beyond importing `my_app.py`. This is the layer to run
on every save.

## Layer 2 — Integration tests (`tests/integration/`)

Two collaborators wired together, still without a browser or a live app:

- `csv_batch_pipeline.robot` — real CSV files under `tests/data/` through
  `analyze_csv_file()` + `get_df_with_highest_kokonaisvoitto()` (real file I/O + pandas
  parsing + `FinanceCalculator`, together). `valid_listings.csv` has a deliberately
  unambiguous best candidate (cheap, high rent, low fee) so the "most profitable" pick is
  checkable without duplicating the app's own ranking logic in the test.
- `listing_extractor_contract.robot` — exercises `listing_extractor.extract_from_url` /
  `extract_from_file` for real, with only `anthropic.Anthropic` stubbed
  (`tests/libraries/ListingExtractorTestLibrary.py`), so response parsing, the
  refusal/empty-response/API-error → `ListingExtractionError` mapping, and mime-type routing
  are all verified without hitting the network.
- `listing_extractor_live_api.robot` *(tag `live-api`, excluded by default)* — an opt-in
  smoke check against the real Anthropic API. It only asserts the result is well-formed
  (has the expected keys) since the target URL isn't a real listing; run it manually with
  `ANTHROPIC_API_KEY` set before releasing a change that touches `listing_extractor.py`'s
  request-building.

## Layer 3 — System tests (`tests/system/`)

Full black-box: `tests/resources/streamlit_app.resource` launches the real
`streamlit run my_app.py` as a subprocess on a free port, waits on `/_stcore/health`, and
drives it with `robotframework-browser` (headless Chromium). `ANTHROPIC_API_KEY` is cleared
for the launched process so listing-autofill tests hit the real "no API key" error path
deterministically, without needing network access or a real key.

- `app_launch_smoke.robot` — the app renders with default values: one results table, two
  charts, three summary metrics, no error/warning alerts on load.
- `manual_entry_flow.robot` — editing a form field reactively updates the summary metrics
  through a real rerun: raising rent raises ROE, raising the sale price raises total profit,
  raising own equity (which only appears in the ROE denominator, not the profit numerator)
  lowers ROE.
- `csv_upload_flow.robot` — uploading a CSV through the real file-uploader widget prefills
  the form with the most profitable listing (same fixture and expectation as the CSV
  integration suite, checked through the browser this time).
- `listing_autofill_flow.robot` — the two deterministic, offline-safe UI paths: clicking
  "fetch" with neither URL nor file shows a warning; clicking it with a URL but no API key
  shows the real Finnish configuration-error message. (The Claude request/response contract
  itself is covered in `listing_extractor_contract.robot`, not here.)

Widget selectors rely on Streamlit's `aria-label` (set from each `st.number_input`/`st.slider`
label) and `data-testid` attributes (`stDataFrame`, `stMetric`, `stAlert`,
`stVegaLiteChart`, `stFileUploaderDropzoneInput`) — inspected directly from a running instance
of the app rather than guessed, so they should stay stable across Streamlit point releases as
long as the widget labels in `my_app.py` don't change.

## Known gaps this suite documents rather than fixes

- **`analyze_csv_file` on a malformed CSV**: a missing `hinta`/`vuokra`/`yhtiövastike` column
  raises a raw `pandas.KeyError` with no user-facing message (`csv_batch_pipeline.robot`,
  tagged `known-issue`, still runs by default). Streamlit will show Python's default traceback
  to the user rather than a Finnish error message. Worth hardening in `analyze_csv_file`
  itself; out of scope for this test-strategy change.

## What's intentionally not covered

- Docker image build/runtime (`Dockerfile`) — no test exercises the container; a CI job
  running `docker build` would be a reasonable separate addition.
- Exact date-dependent values (e.g. "first positive month is 28.08.2030") — schedules are
  built from `datetime.now()`, so system tests assert format/shape and directional deltas
  (`Should Match Regexp`, "increased/decreased after changing X") rather than fixed dates,
  to stay stable regardless of which day the suite runs.
