# Sijoitusasuntolaskuri

A Streamlit web app for analyzing the profitability of a buy-to-let (rental investment) apartment purchase in Finland. The UI is in Finnish.

Given a loan amount, interest rate, rent, housing company fee ("yhtiövastike"), maintenance costs, and an estimated future selling price, the app:

- Computes a monthly annuity loan amortization schedule over the loan term.
- Tracks monthly cash flow (rent, interest, housing fee, loan setup cost, maintenance) after an assumed tax rate.
- Calculates cumulative profit and total profit (including a simulated sale of the apartment) over time.
- Shows the return on equity (ROE %) and the first month the investment turns cumulatively profitable.
- Plots total profit, cumulative profit, and ROE % over time.

You can either enter the property/loan details manually in the form, or upload a CSV file listing multiple candidate apartments (columns: `hinta`, `vuokra`, `yhtiövastike`); the app then evaluates all of them and pre-fills the form with the most profitable one at a 5-year horizon.

You can also paste a link to a listing (or upload a PDF/screenshot of one) and have Claude read it and pre-fill the purchase price, rent, and housing fee fields automatically.

## Running locally (without Docker)

Requires Python 3.11+.

```bash
pip install -r requirements.txt
streamlit run my_app.py
```

The app will be available at http://localhost:8501.

### Listing autofill (optional)

To use the "Hae tiedot ilmoituksesta" (fetch listing info) feature, the app needs an Anthropic API key. Without a key set, the rest of the app works as usual — only that feature will show an error if used.

You can provide the key either as an environment variable:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
streamlit run my_app.py
```

or via a `.env` file (loaded automatically):

```bash
cp .env.example .env
# then edit .env and set your key
streamlit run my_app.py
```

## Running with Docker

### Build the image

```bash
docker build -t sijoitusasuntolaskuri .
```

### Run the container

```bash
docker run --rm -p 8501:8501 sijoitusasuntolaskuri
```

Then open http://localhost:8501 in your browser.

### Listing autofill (optional)

To use the listing autofill feature in Docker, pass in your Anthropic API key via a `.env` file instead of baking it into the image:

```bash
cp .env.example .env
# then edit .env and set your key

docker run --rm -p 8501:8501 --env-file .env sijoitusasuntolaskuri
```
