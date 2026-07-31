*** Settings ***
Documentation     Unit tests for FinanceCalculator.calculate_data (my_app.py), the second stage of
...               the pipeline that turns a loan schedule into monthly cash flow / cumulative
...               profit / ROE. Loan schedules are built synthetically (Build Monthly Loan Records)
...               so these tests exercise calculate_data's own rules in isolation from the annuity
...               amortization formula, which is covered separately in annuity_loan_payments.robot.
Library           ../libraries/FinanceCalculatorLibrary.py
Library           Collections

*** Test Cases ***
Monthly Income Combines Rent Fee Interest Housing Fee And Maintenance
    [Documentation]    tulo = korko + yhtiövastike + kulu + vuokra + loan_cost + huolto_ja_ylläpito, hand-computed.
    ${row}=    Create Dictionary    pvm=10.01.2024    total=300    lyhennys=200    korko=-100    kulu=-5    pääoma=-9800
    ${records}=    Create List    ${row}
    ${result}=    Calculate Data From Records    ${records}    vuokra=500    yhtiovastike=120
    ...    start_pvm=10.01.2024    end_pvm=10.01.2024    myyntihinta=65000    valityspalkkio=0.03
    ...    capital=2000    maintenance_cost=-240    loan_cost=0
    Length Should Be    ${result}    1
    ${row}=    Get From List    ${result}    0
    # korko(-100) + yhtiövastike(-120) + kulu(-5) + vuokra(500) + loan_cost(0) + huolto(-20) = 255
    Should Be Equal As Numbers    ${row}[tulo]    255.0    precision=6
    Should Be Equal As Numbers    ${row}[tulo_verojen_jälkeen]    178.5    precision=6
    Should Be Equal As Numbers    ${row}[voitto_lainan_lyhennyksen_jälkeen]    -21.5    precision=6
    Should Be Equal As Numbers    ${row}[kumulatiivinen_voitto]    -21.5    precision=6
    # kokonaisvoitto = myyntihinta - valityspalkkio(0.03*65000=1950) + pääoma(-9800) + kumulatiivinen_voitto(-21.5)
    Should Be Equal As Numbers    ${row}[kokonaisvoitto]    53228.5    precision=6
    # (kokonaisvoitto - capital) / capital * 100 = (53228.5 - 2000) / 2000 * 100
    Should Be Equal As Numbers    ${row}[kokonaisvoitto_prosentti]    2561.425    precision=6

Cumulative Profit Accumulates Across Months
    ${records}=    Build Monthly Loan Records    n_months=3    korko=-50    lyhennys=100    kulu=0    paaoma_start=-9700    paaoma_step=100
    ${result}=    Calculate Data From Records    ${records}    vuokra=400    yhtiovastike=100
    ...    start_pvm=10.01.2024    end_pvm=10.03.2024    maintenance_cost=0    loan_cost=0
    Length Should Be    ${result}    3
    # Monthly voitto = (vuokra 400 + korko -50 + yhtiövastike -100) * 0.7 - lyhennys 100 = 75, every month here.
    ${row0}=    Get From List    ${result}    0
    ${row1}=    Get From List    ${result}    1
    ${row2}=    Get From List    ${result}    2
    Should Be Equal As Numbers    ${row0}[kumulatiivinen_voitto]    75.0    precision=6
    Should Be Equal As Numbers    ${row1}[kumulatiivinen_voitto]    150.0    precision=6
    Should Be Equal As Numbers    ${row2}[kumulatiivinen_voitto]    225.0    precision=6

Roe Percentage Is Not A Number When Equity Is Zero
    [Documentation]    kokonaisvoitto_prosentti divides by oma_pääoma; the app guards against
    ...                a divide-by-zero by returning NaN instead of raising or returning inf.
    ${records}=    Build Monthly Loan Records    n_months=1
    ${result}=    Calculate Data From Records    ${records}    vuokra=400    yhtiovastike=100
    ...    start_pvm=10.01.2024    end_pvm=10.01.2024    capital=0
    ${row}=    Get From List    ${result}    0
    ${is_nan}=    Is Nan    ${row}[kokonaisvoitto_prosentti]
    Should Be True    ${is_nan}

Date Filter Keeps Only Rows Within The Investment Window
    ${records}=    Build Monthly Loan Records    n_months=6    start_pvm=10.01.2024
    ${result}=    Calculate Data From Records    ${records}    vuokra=400    yhtiovastike=100
    ...    start_pvm=10.02.2024    end_pvm=10.04.2024
    Length Should Be    ${result}    3
    ${first_row}=    Get From List    ${result}    0
    ${last_row}=    Get From List    ${result}    -1
    Should Be Equal As Strings    ${first_row}[pvm]    10.02.2024
    Should Be Equal As Strings    ${last_row}[pvm]    10.04.2024

Maintenance Cost Is Spread Evenly Across Every Month Of The Investment
    [Documentation]    Unlike loan_cost, huolto_ja_ylläpito = maintenance_cost / 12 is applied to
    ...                every row, for as long as the investment horizon runs - not just year one.
    ${records}=    Build Monthly Loan Records    n_months=15    start_pvm=10.01.2024
    ${result}=    Calculate Data From Records    ${records}    vuokra=400    yhtiovastike=100
    ...    start_pvm=10.01.2024    end_pvm=10.03.2025    maintenance_cost=-1200
    ${first_row}=    Get From List    ${result}    0
    ${last_row}=    Get From List    ${result}    -1
    Should Be Equal As Numbers    ${first_row}[huolto_ja_ylläpito]    -100.0    precision=6
    Should Be Equal As Numbers    ${last_row}[huolto_ja_ylläpito]    -100.0    precision=6

Loan Setup Cost Is Spread Only Over The First Twelve Months
    [Documentation]    loan_cost is divided across min(12, len(data)) rows and zero afterwards,
    ...                a front-loaded one-off cost rather than an ongoing monthly one.
    ${records}=    Build Monthly Loan Records    n_months=15    start_pvm=10.01.2024
    ${result}=    Calculate Data From Records    ${records}    vuokra=400    yhtiovastike=100
    ...    start_pvm=10.01.2024    end_pvm=10.03.2025    loan_cost=-1200
    ${month_12}=    Get From List    ${result}    11
    ${month_13}=    Get From List    ${result}    12
    Should Be Equal As Numbers    ${month_12}[loan_cost]    -100.0    precision=6
    Should Be Equal As Numbers    ${month_13}[loan_cost]    0.0    precision=6
