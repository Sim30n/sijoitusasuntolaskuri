"""Robot Framework keyword library wrapping the pure calculation code in my_app.py.

Lets unit/integration suites call FinanceCalculator (and the CSV batch-mode
helpers) as Robot keywords and assert on plain Python dicts/lists, without a
running Streamlit server or a browser.
"""
import math
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd
from dateutil.relativedelta import relativedelta

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from my_app import (  # noqa: E402  (path must be extended first)
    FinanceCalculator,
    analyze_csv_file,
    get_df_with_highest_kokonaisvoitto,
)


class FinanceCalculatorLibrary:
    """Keywords for testing the finance calculation core in isolation."""

    # calculate_data's **kwargs arrive from Robot as plain strings; FinanceCalculator does its
    # own float(...) casting only for the positional args, so numeric kwargs must be coerced
    # here or pandas silently builds string columns that blow up on the first arithmetic op.
    _FLOAT_KWARGS = {"myyntihinta", "yhtiolainanosuus", "valityspalkkio", "capital", "loan_cost", "maintenance_cost"}
    _INT_KWARGS = {"zero_rent_amount"}

    @classmethod
    def _coerce_kwargs(cls, kwargs):
        coerced = dict(kwargs)
        for key in cls._FLOAT_KWARGS:
            if key in coerced and coerced[key] is not None:
                coerced[key] = float(coerced[key])
        for key in cls._INT_KWARGS:
            if key in coerced and coerced[key] is not None:
                coerced[key] = int(coerced[key])
        return coerced

    def calculate_annuity_loan_payments(self, principal, annual_interest_rate, loan_term_years, monthly_fee):
        """Runs FinanceCalculator.calculate_annuity_loan_payments, returns a dict of parallel lists."""
        payments, interests, loan_left, loan_pay, dates, fees = FinanceCalculator.calculate_annuity_loan_payments(
            float(principal), float(annual_interest_rate), float(loan_term_years), float(monthly_fee)
        )
        return {
            "payments": payments,
            "interests": interests,
            "loan_left": loan_left,
            "loan_pay": loan_pay,
            "dates": dates,
            "fees": fees,
            "n_months": len(payments),
        }

    def loan_schedule_to_dataframe(self, schedule):
        """Builds the loan DataFrame shape my_app.py assembles before calling calculate_data."""
        return pd.DataFrame({
            "pvm": schedule["dates"],
            "total": schedule["payments"],
            "lyhennys": schedule["loan_pay"],
            "korko": schedule["interests"],
            "kulu": schedule["fees"],
            "pääoma": schedule["loan_left"],
        })

    def calculate_investment_data(self, principal, annual_interest_rate, loan_term_years, monthly_fee,
                                   vuokra, yhtiovastike, **kwargs):
        """Runs the full pipeline (loan schedule -> calculate_data) my_app.py wires together, as one call."""
        schedule = self.calculate_annuity_loan_payments(principal, annual_interest_rate, loan_term_years, monthly_fee)
        loan_df = self.loan_schedule_to_dataframe(schedule)
        result_df = FinanceCalculator.calculate_data(
            loan_df, float(vuokra), float(yhtiovastike), **self._coerce_kwargs(kwargs)
        )
        return self._records(result_df)

    def build_monthly_loan_records(self, n_months, start_pvm="10.01.2024", korko=-50.0, lyhennys=100.0,
                                    kulu=-2.5, paaoma_start=-10000.0, paaoma_step=100.0):
        """Builds a synthetic loan-schedule (list of row dicts) for unit-testing calculate_data
        in isolation from calculate_annuity_loan_payments' own formula.
        """
        start_date = datetime.strptime(start_pvm, "%d.%m.%Y")
        records = []
        paaoma = float(paaoma_start)
        for i in range(int(n_months)):
            date = start_date + relativedelta(months=i)
            records.append({
                "pvm": date.strftime("%d.%m.%Y"),
                "total": float(lyhennys) - float(korko),
                "lyhennys": float(lyhennys),
                "korko": float(korko),
                "kulu": float(kulu),
                "pääoma": paaoma,
            })
            paaoma += float(paaoma_step)
        return records

    def calculate_data_from_records(self, loan_records, vuokra, yhtiovastike, **kwargs):
        """Runs calculate_data directly against a hand-built loan schedule (list of row dicts).

        Use this to unit-test calculate_data's own business rules (rent/tax/sale math)
        in isolation from the annuity amortization formula.
        """
        loan_df = pd.DataFrame(loan_records)
        result_df = FinanceCalculator.calculate_data(
            loan_df, float(vuokra), float(yhtiovastike), **self._coerce_kwargs(kwargs)
        )
        return self._records(result_df)

    def analyze_csv(self, csv_path):
        """Runs analyze_csv_file() against a real CSV file (file IO + pandas + calculator together)."""
        data_list, _loan = analyze_csv_file(csv_path)
        return [self._records(df) for df in data_list]

    def highest_kokonaisvoitto_row(self, csv_path, years_ahead=5):
        """Runs the CSV -> pick-most-profitable-apartment pipeline used to prefill the form."""
        data_list, _loan = analyze_csv_file(csv_path)
        target_date = datetime.now() + relativedelta(years=int(years_ahead))
        best_df = get_df_with_highest_kokonaisvoitto(data_list, target_date)
        if best_df is None or best_df.empty:
            return None
        return self._records(best_df)[0]

    @staticmethod
    def is_nan(value):
        """Returns True if value is a float NaN. Robot's `Should Be True` can't compare NaN with `==`."""
        return isinstance(value, float) and math.isnan(value)

    @staticmethod
    def _records(df):
        records = df.to_dict(orient="records")
        for row in records:
            if "pvm" in row and pd.notna(row["pvm"]):
                row["pvm"] = row["pvm"].strftime("%d.%m.%Y")
        return records
