# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Streamlit web app (UI in Finnish) for analyzing the profitability of a buy-to-let apartment
purchase in Finland. Given loan terms, rent, housing company fee, maintenance costs, and an
estimated future selling price, it computes an amortization schedule, monthly after-tax cash
flow, cumulative/total profit, and return on equity (ROE %) over time.

The entire app is two files: `my_app.py` (Streamlit UI + finance math) and
`listing_extractor.py` (Claude-powered autofill from a listing URL or uploaded file).

## Commands

```bash
# Install deps (Python 3.11+ required)
pip install -r requirements.txt

# Run the app locally (http://localhost:8501)
streamlit run my_app.py

# Docker
docker build -t sijoitusasuntolaskuri .
docker run --rm -p 8501:8501 --env-file .env sijoitusasuntolaskuri
```

There is no test suite, linter, or type checker configured in this repo. Verify changes by
running the app and exercising the relevant UI flow in a browser (see the `run` skill).

The listing-autofill feature requires `ANTHROPIC_API_KEY`, set via env var or a `.env` file
(copy `.env.example`, loaded automatically by `python-dotenv`). Without a key, that one feature
degrades to an error message; the rest of the calculator works normally.

## Architecture

### `my_app.py` — finance model + UI

`FinanceCalculator` (stateless, all `@staticmethod`) does the actual math in two stages that
feed into each other:

1. `calculate_annuity_loan_payments(principal, annual_interest_rate, loan_term_years, monthly_fee)`
   builds the month-by-month annuity amortization schedule (standard loan payment formula),
   returning parallel lists (payment, interest, remaining principal, principal-only payment,
   date, fee) starting from `datetime.now()`.
2. `calculate_data(data, vuokra, yhtiovastike, ...)` takes that schedule as a DataFrame and
   layers on rent, housing fee, maintenance, loan setup cost, a flat 30% tax haircut, and a
   simulated sale (`myyntihinta` minus `valityspalkkio` agent commission) to produce cumulative
   and total profit columns, then filters to the `start_pvm`–`end_pvm` window.

`main()` renders the Streamlit form and wires the two together: it builds a loan schedule from
the form inputs, runs `calculate_data`, then renders the result as a table (`st.dataframe`) and
two line charts (profit curves; ROE % curve). It also computes summary metrics: first month
cumulative profit turns positive, and profit/ROE at a user-chosen `sijoitusaika` (investment
horizon) target date.

There are two ways to seed the form besides manual entry, both optional and composable:

- **CSV batch mode** (`analyze_csv_file`): upload a `;`-delimited CSV with columns `hinta`,
  `vuokra`, `yhtiövastike`, listing multiple candidate apartments. Each row is run through the
  same two-stage calculation with hardcoded assumptions (2.8% interest, 20-year term, 5-year
  evaluation horizon), and `get_df_with_highest_kokonaisvoitto` picks the most profitable one to
  pre-fill the form.
- **Listing autofill**: paste a listing URL or upload a PDF/screenshot; `listing_extractor` calls
  Claude to extract `purchase_price`/`monthly_rent`/`housing_fee`, which overrides whatever the
  CSV step (or the hardcoded defaults) put in the form. This override happens *after* the CSV
  branch, so listing-extracted fields always win over CSV-derived ones.

All internal DataFrame columns and Streamlit labels are in Finnish — know this vocabulary when
reading or modifying `calculate_data`:

| Column | Meaning |
|---|---|
| `pvm` | date |
| `korko` | interest (negative) |
| `lyhennys` | principal-only payment |
| `pääoma` | remaining loan principal (negative) |
| `kulu` | monthly loan fee |
| `vuokra` | rent |
| `yhtiövastike` | housing company fee (negative) |
| `myyntihinta` | (estimated) selling price |
| `valityspalkkio` | agent's commission on sale |
| `oma_pääoma` | equity/capital invested |
| `huolto_ja_ylläpito` | maintenance/upkeep cost |
| `tulo` | monthly income before tax |
| `tulo_verojen_jälkeen` | monthly income after flat 30% tax |
| `voitto_lainan_lyhennyksen_jälkeen` | monthly profit after principal repayment |
| `kumulatiivinen_voitto` | cumulative profit |
| `kokonaisvoitto` | total profit including simulated sale |
| `kokonaisvoitto_prosentti` | ROE %, relative to `oma_pääoma` |

### `listing_extractor.py` — Claude-powered listing autofill

Uses the `anthropic` SDK (model set by the `MODEL` constant, currently `claude-opus-5`) with
structured output: `output_config.format` is a `json_schema` matching `LISTING_SCHEMA`
(`purchase_price`, `monthly_rent`, `housing_fee`, `notes`, all nullable — the model is instructed
never to guess a missing value).

- `extract_from_url(url)` — passes the URL as text plus the `web_fetch` tool so Claude fetches
  and reads the page itself.
- `extract_from_file(uploaded_file)` — base64-encodes an uploaded PDF or image
  (png/jpeg/webp/gif) and sends it as a `document`/`image` content block.

Both funnel through `_run`, which streams the response and raises `ListingExtractionError` (a
Finnish-message exception shown directly in the Streamlit UI) on missing API key, API errors, or
a model refusal. `my_app.py` catches this exception at the call site rather than crashing the app.

## Conventions

- UI strings, DataFrame column names, and docstrings in these two files are Finnish; keep new
  user-facing text and financial-domain fields consistent with that (English is fine for code
  identifiers/comments elsewhere).
- Keep `Dockerfile`'s `COPY my_app.py listing_extractor.py .` in sync if new Python modules are
  added — it copies files explicitly rather than the whole directory.
