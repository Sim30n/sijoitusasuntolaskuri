import streamlit as st
import pandas as pd
import numpy as np

from datetime import datetime, timedelta
from dateutil.relativedelta import relativedelta


class FinanceCalculator:
    def __init__(self):
        pass

    @staticmethod
    def calculate_annuity_loan_payments(principal, annual_interest_rate, loan_term_years, monthly_fee):
        # Convert annual interest rate to decimal and calculate monthly interest rate
        loan_term_months = int(round(loan_term_years)) * 12
        monthly_interest_rate = (annual_interest_rate / 100) / 12

        # Calculate monthly payment using the loan payment formula
        if monthly_interest_rate > 0:
            monthly_payment = principal * (monthly_interest_rate * (1 + monthly_interest_rate) ** loan_term_months) / \
                            ((1 + monthly_interest_rate) ** loan_term_months - 1)
        else:
            # If interest rate is 0, the payment is simply the principal divided equally over the months
            monthly_payment = principal / loan_term_months

        # Initialize lists to store monthly details
        monthly_date = []
        monthly_payments = []
        monthly_interests = []
        monthly_loan_left = []
        monthly_loan_pay = []
        monthly_fee_list = []

        # Starting date
        current_date = datetime.now()

        # Calculate monthly payment and interest for each month
        for month in range(1, loan_term_months + 1):
            # Calculate monthly interest
            monthly_interest = principal * monthly_interest_rate
            # Calculate payment towards principal
            payment_no_interest = monthly_payment - monthly_interest
            # Update remaining principal
            remaining_principal = principal - payment_no_interest
            # Ensure the last payment covers any rounding differences
            if month == loan_term_months:
                payment_no_interest += remaining_principal
                monthly_payment = payment_no_interest + monthly_interest
                remaining_principal = 0

            # Append date for the current month
            monthly_date.append(current_date.strftime("%d.%m.%Y"))
            # Append payment details to lists
            monthly_payments.append(monthly_payment)
            monthly_interests.append(-monthly_interest)
            monthly_loan_left.append(-remaining_principal)
            monthly_loan_pay.append(payment_no_interest)
            monthly_fee_list.append(-monthly_fee)
            # Update the principal and date for the next iteration
            principal = remaining_principal
            #current_date = current_date + timedelta(days=30)  # Approximate a month as 30 days
            current_date = current_date + relativedelta(months=1)
        return monthly_payments, monthly_interests, monthly_loan_left, monthly_loan_pay, monthly_date, monthly_fee_list

    @staticmethod
    def calculate_data(data,
                    vuokra,
                    yhtiovastike,
                    start_pvm="10.01.2024",
                    end_pvm="10.07.2042",
                    myyntihinta=65000,
                    yhtiolainanosuus=3000,
                    valityspalkkio=0.03,
                    capital=0,
                    zero_rent_amount=0,
                    loan_cost=0,
                    maintenance_cost=0):
        date_format = "%d.%m.%Y"
        data["pvm"] = pd.to_datetime(data["pvm"], format=date_format)
        try:
            data["pääoma"] = data["pääoma"].str.replace(" ", "")
        except AttributeError:
            pass
        data["oma_pääoma"] = capital
        data["vuokra"] = vuokra
        if zero_rent_amount > 0:
            # Find all indices for each year
            data = data.sort_values("pvm")
            data["vuokra"] = vuokra  # default
            years = data["pvm"].dt.year.unique()
            for year in years:
                year_idx = data[data["pvm"].dt.year == year].index
                # Set vuokra=0 for the first zero_rent_amount months of each year
                zero_months_idx = year_idx[:zero_rent_amount]
                data.loc[zero_months_idx, "vuokra"] = 0

        data["yhtiövastike"] = -yhtiovastike # -203.2
        data["myyntihinta"] = myyntihinta
        #data["yhtiolainaosuus"] = yhtiolainanosuus
        data["valityspalkkio"] = valityspalkkio * (data["myyntihinta"])
        try:
            data = data.replace({',': '.'}, regex=True)
        except AttributeError:
            pass
        columns_to_convert = data.columns.difference(["pvm"])
        data[columns_to_convert] = data[columns_to_convert].astype(float)

        data["huolto_ja_ylläpito"] = maintenance_cost / 12

        # Set loan_cost divided equally for the first 12 rows, 0 for the rest
        data["loan_cost"] = 0.0  # Ensure float dtype to avoid FutureWarning
        if len(data) > 0:
            n = min(12, len(data))
            data.loc[data.index[:n], "loan_cost"] = loan_cost / n
        data["tulo"] = data["korko"] + data["yhtiövastike"] + data["kulu"] + data["vuokra"] + data["loan_cost"] + data["huolto_ja_ylläpito"]
        data["tulo_verojen_jälkeen"] = data["tulo"] * 0.7
        data["voitto_lainan_lyhennyksen_jälkeen"] = data["tulo_verojen_jälkeen"] - data["lyhennys"]
        #data["ROE"] = data["voitto_lainan_lyhennyksen_jälkeen"] / data["oma_pääoma"] * 100
        data["kumulatiivinen_voitto"] = data["voitto_lainan_lyhennyksen_jälkeen"].cumsum()
        data["kokonaisvoitto"] = data["myyntihinta"] - data["valityspalkkio"] + data["pääoma"] + data["kumulatiivinen_voitto"]
        data["kokonaisvoitto_prosentti"] = np.where(
            data["oma_pääoma"] != 0,
            (data["kokonaisvoitto"] - data["oma_pääoma"]) / data["oma_pääoma"] * 100,
            np.nan
        )
        start_date = pd.to_datetime(start_pvm, format="%d.%m.%Y")
        end_date = pd.to_datetime(end_pvm, format="%d.%m.%Y")
        selected_rows = data[(data["pvm"] >= start_date) & (data["pvm"] <= end_date)]
        selected_rows = selected_rows.reset_index(drop=True)
        return selected_rows


def analyze_csv_file(file):
    csv_loan_term_years = 20
    end_pvm = (datetime.now() + relativedelta(years=csv_loan_term_years + 1)).strftime("%d.%m.%Y")

    df = pd.read_csv(file, delimiter=';', quotechar='"')
    df['hinta'] = df['hinta'].astype(int)
    df['vuokra'] = df['vuokra'].astype(int)
    df['yhtiövastike'] = df['yhtiövastike'].astype(int)
    finance_calculator = FinanceCalculator()
    finance_data_list = []
    for index, row in df.iterrows():
        loan = finance_calculator.calculate_annuity_loan_payments(row['hinta'], 2.8, csv_loan_term_years, 2.5)
        loan_df = pd.DataFrame({'pvm': loan[4],
                       'total': loan[0],
                       'lyhennys': loan[3],
                       'korko': loan[1],
                       'kulu': loan[5],
                       'pääoma': loan[2]})
        finance_data = finance_calculator.calculate_data(loan_df,
                                          vuokra=row['vuokra'],
                                          yhtiovastike=row['yhtiövastike'],
                                          myyntihinta=row['hinta'],
                                          end_pvm=end_pvm,
                                          capital=1000,
                                          valityspalkkio=0.06,
                                          zero_rent_amount=1,
                                          loan_cost=690,
                                          maintenance_cost=500)
        finance_data_list.append(finance_data)
    return finance_data_list, loan


def get_df_with_highest_kokonaisvoitto(finance_data_list, target_date):
    max_value = None
    max_df = None
    for df in finance_data_list:
        if df.empty:
            continue
        closest_idx = (df["pvm"] - target_date).abs().idxmin()
        current_max = df.loc[closest_idx, "kokonaisvoitto"]
        if (max_value is None) or (current_max > max_value):
            max_value = current_max
            max_df = df
    return max_df


def main():
    uploaded_file = st.file_uploader("Lataa CSV-tiedosto kaikista kohteista", type=["csv"])

    if uploaded_file is not None:
        data_list, loan = analyze_csv_file(uploaded_file)
        csv_default_target_date = datetime.now() + relativedelta(years=5)
        highest_kokonaisvoitto_df = get_df_with_highest_kokonaisvoitto(data_list, csv_default_target_date)
        lainan_suuruus = -highest_kokonaisvoitto_df["pääoma"].iloc[0] - highest_kokonaisvoitto_df["oma_pääoma"].iloc[0]
        korko = 2.8
        vuotta = 20
        kulut = 2.5
        vuokra = highest_kokonaisvoitto_df["vuokra"].max()
        yhtiovastike = -highest_kokonaisvoitto_df["yhtiövastike"].iloc[0]
        myyntihinta = highest_kokonaisvoitto_df["myyntihinta"].iloc[0]
        capital = highest_kokonaisvoitto_df["oma_pääoma"].iloc[0]
        valityspalkkio = 0.06
    else:
        lainan_suuruus = 62000
        korko = 2.8
        vuotta = 20
        kulut = 2.5
        vuokra = 460
        yhtiovastike = 112
        myyntihinta = 64000
        capital = 2000
        valityspalkkio = 0.06
    
    st.subheader("Kiinteistön tiedot")
    capital = st.number_input("Oma pääoma (€)", min_value=0, value=int(capital), step=100)

    st.subheader("Laina")
    col1, col2, col3 = st.columns(3)
    lainan_suuruus = col1.number_input("Lainan suuruus (€)", min_value=0, value=int(lainan_suuruus), step=1000)
    vuotta = col2.number_input("Laina-aika (vuotta)", min_value=1, value=int(vuotta), step=1)
    kulut = col3.number_input("Kuukausittaiset lainakulut (€/kk)", min_value=0.0, value=float(kulut), step=0.1, format="%.2f")
    korko = st.slider("Korko (%)", min_value=0.0, max_value=15.0, value=float(korko), step=0.1, format="%.2f")
    loan_cost = -int(st.number_input("Lainan perustamiskustannus (€)", min_value=0, step=1, value=690))

    st.subheader("Vuokraus")
    col1, col2, col3 = st.columns(3)
    vuokra = col1.number_input("Vuokra (€/kk)", min_value=0, value=int(vuokra), step=10)
    yhtiovastike = col2.number_input("Yhtiövastike (€/kk)", min_value=0, value=int(yhtiovastike), step=1)
    zero_rent_amount = int(col3.number_input("Tyhjäkäyntikuukaudet (kk/v)", min_value=0, step=1, value=1))

    st.subheader("Ylläpito")
    maintenance_cost = -int(st.number_input("Korjaus- ja ylläpitokustannukset (€/v)", min_value=0, step=1, value=500))

    st.subheader("Myynti")
    col1, col2 = st.columns(2)
    myyntihinta = col1.number_input("Arvioitu myyntihinta laina-ajan lopussa (€)", min_value=0, value=int(myyntihinta), step=1000)
    valityspalkkio_prosentti = col2.number_input("Välityspalkkio (%)", min_value=0.0, max_value=100.0, value=float(valityspalkkio * 100), step=0.5, format="%.2f")
    valityspalkkio = valityspalkkio_prosentti / 100
    sijoitusaika = st.number_input("Sijoitusajan pituus (vuotta) - milloin tarkastellaan kokonaisvoittoa", min_value=1, value=5, step=1)
    target_date = datetime.now() + relativedelta(years=int(sijoitusaika))

    monthly_payment = FinanceCalculator.calculate_annuity_loan_payments(lainan_suuruus, korko, vuotta, kulut)

    monthly_payment_df = pd.DataFrame({'pvm': monthly_payment[4],
                       'total': monthly_payment[0],
                       'lyhennys': monthly_payment[3],
                       'korko': monthly_payment[1],
                       'kulu': monthly_payment[5],
                       'pääoma': monthly_payment[2]})

    end_pvm = (datetime.now() + relativedelta(years=int(max(vuotta, sijoitusaika)) + 1)).strftime("%d.%m.%Y")

    all_years = FinanceCalculator.calculate_data(monthly_payment_df,
                               vuokra=vuokra,
                               yhtiovastike=yhtiovastike,
                               myyntihinta=myyntihinta,
                               end_pvm=end_pvm,
                               capital=capital,
                               valityspalkkio=valityspalkkio,
                               zero_rent_amount=zero_rent_amount,
                               loan_cost=loan_cost,
                               maintenance_cost=maintenance_cost)

    #df = pd.DataFrame(np.random.randn(50, 20), columns=("col %d" % i for i in range(20)))

    #st.dataframe(data=monthly_payment_df,
    #             use_container_width=True)  # Same as st.write(df)

    st.dataframe(data=all_years,
                 use_container_width=True)  # Same as st.write(df)

    st.line_chart(
        data=all_years,
        x="pvm",
        y=[
            "kokonaisvoitto",
            "kumulatiivinen_voitto",
            "voitto_lainan_lyhennyksen_jälkeen"
           ],
        use_container_width=True
    )

    st.line_chart(
        data=all_years,
        x="pvm",
        y=[
            "kokonaisvoitto_prosentti",
           ],
        use_container_width=True
    )

    first_positive_month = all_years[(all_years["kokonaisvoitto"] - capital) > 0]["pvm"].min()

    if pd.isna(first_positive_month):
        first_positive_month_str = "Ei löytynyt"
    else:
        first_positive_month_str = first_positive_month.strftime('%d.%m.%Y')

    st.subheader("Yhteenveto")

    if all_years.empty:
        st.warning("Ei tietoja valitulle sijoitusajalle.")
    else:
        closest_idx = (all_years["pvm"] - target_date).abs().idxmin()
        snapshot_row = all_years.loc[closest_idx]
        snapshot_date_str = snapshot_row["pvm"].strftime('%d.%m.%Y')

        col1, col2, col3 = st.columns(3)
        col1.metric("Ensimmäinen positiivinen kuukausi", first_positive_month_str)
        col2.metric(f"Kokonaisvoitto ({snapshot_date_str})", f"{(snapshot_row['kokonaisvoitto'] - capital):,.0f} €")
        col3.metric(f"ROE ({snapshot_date_str})", f"{snapshot_row['kokonaisvoitto_prosentti']:,.1f} %")


if __name__ == "__main__":
    main()
