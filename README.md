# Sijoitusasuntolaskuri

A Streamlit web app for analyzing the profitability of a buy-to-let (rental investment) apartment purchase in Finland. The UI is in Finnish.

Given a loan amount, interest rate, rent, housing company fee ("yhtiövastike"), maintenance costs, and an estimated future selling price, the app:

- Computes a monthly annuity loan amortization schedule over the loan term.
- Tracks monthly cash flow (rent, interest, housing fee, loan setup cost, maintenance) after an assumed tax rate.
- Calculates cumulative profit and total profit (including a simulated sale of the apartment) over time.
- Shows the return on equity (ROE %) and the first month the investment turns cumulatively profitable.
- Plots total profit, cumulative profit, and ROE % over time.

You can either enter the property/loan details manually in the form, or upload a CSV file listing multiple candidate apartments (columns: `hinta`, `vuokra`, `yhtiövastike`); the app then evaluates all of them and pre-fills the form with the most profitable one at a 5-year horizon.

## Running locally (without Docker)

Requires Python 3.11+.

```bash
pip install -r requirements.txt
streamlit run my_app.py
```

The app will be available at http://localhost:8501.

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
