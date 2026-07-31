*** Settings ***
Documentation     Unit tests for FinanceCalculator.calculate_annuity_loan_payments (my_app.py).
...               Pure math, no I/O: verifies the amortization schedule against values computed
...               independently from the textbook annuity-payment formula, and checks the
...               invariants the rest of the app relies on (schedule length, principal fully
...               repaid, negative sign conventions).
Library           ../libraries/FinanceCalculatorLibrary.py
Library           Collections

*** Test Cases ***
Monthly Payment Matches Independent Annuity Formula
    [Documentation]    100000e, 5%, 10 years, no fee -> pmt = P*r(1+r)^n / ((1+r)^n - 1), computed by hand.
    ${schedule}=    Calculate Annuity Loan Payments    100000    5    10    0
    ${first_payment}=    Get From List    ${schedule}[payments]    0
    Should Be Equal As Numbers    ${first_payment}    1060.6551523907553    precision=6

Small Known Case Matches Independent Reference Value
    [Documentation]    1200e, 12%, 1 year -> pmt = 106.61854641401, computed by hand.
    ${schedule}=    Calculate Annuity Loan Payments    1200    12    1    0
    ${first_payment}=    Get From List    ${schedule}[payments]    0
    Should Be Equal As Numbers    ${first_payment}    106.61854641401    precision=6

Zero Interest Rate Splits Principal Evenly With No Interest Charged
    ${schedule}=    Calculate Annuity Loan Payments    60000    0    20    0
    FOR    ${interest}    IN    @{schedule}[interests]
        Should Be Equal As Numbers    ${interest}    0
    END
    ${first_payment}=    Get From List    ${schedule}[payments]    0
    Should Be Equal As Numbers    ${first_payment}    250.0    precision=6

Schedule Has One Row Per Month Of The Loan Term
    ${schedule}=    Calculate Annuity Loan Payments    50000    3.5    7    2.5
    Should Be Equal As Integers    ${schedule}[n_months]    84

Remaining Principal Reaches Exactly Zero At Loan End
    ${schedule}=    Calculate Annuity Loan Payments    75000    4.2    15    3
    ${last_loan_left}=    Get From List    ${schedule}[loan_left]    -1
    Should Be Equal As Numbers    ${last_loan_left}    0

Sum Of Principal Payments Equals The Original Loan Amount
    [Documentation]    The amortization must fully repay the loan by the final month, no more, no less.
    ${schedule}=    Calculate Annuity Loan Payments    100000    5    10    0
    ${total_principal_paid}=    Evaluate    sum($schedule["loan_pay"])
    Should Be Equal As Numbers    ${total_principal_paid}    100000    precision=4

First Month Interest Equals Principal Times The Monthly Rate
    ${schedule}=    Calculate Annuity Loan Payments    100000    6    10    0
    ${first_interest}=    Get From List    ${schedule}[interests]    0
    # 100000 * (6% / 12) = 500, stored as a negative outflow.
    Should Be Equal As Numbers    ${first_interest}    -500.0    precision=6

Monthly Fee Is Recorded As A Negative Cost Every Month
    ${schedule}=    Calculate Annuity Loan Payments    20000    3    5    4.5
    FOR    ${fee}    IN    @{schedule}[fees]
        Should Be Equal As Numbers    ${fee}    -4.5
    END

Loan Term In Years Is Rounded To The Nearest Whole Year
    [Documentation]    my_app.py does int(round(loan_term_years)) before multiplying by 12 -
    ...                document that fractional years snap to the nearest year, not truncate.
    ${schedule_down}=    Calculate Annuity Loan Payments    10000    5    10.4    0
    Should Be Equal As Integers    ${schedule_down}[n_months]    120
    ${schedule_up}=    Calculate Annuity Loan Payments    10000    5    10.6    0
    Should Be Equal As Integers    ${schedule_up}[n_months]    132

Loan Schedule Dates Advance One Calendar Month At A Time
    ${schedule}=    Calculate Annuity Loan Payments    10000    5    2    0
    ${first_date}=    Get From List    ${schedule}[dates]    0
    ${second_date}=    Get From List    ${schedule}[dates]    1
    ${first}=    Evaluate    datetime.datetime.strptime('''${first_date}''', '%d.%m.%Y')    modules=datetime
    ${second}=    Evaluate    datetime.datetime.strptime('''${second_date}''', '%d.%m.%Y')    modules=datetime
    ${months_apart}=    Evaluate    (($second.year - $first.year) * 12) + ($second.month - $first.month)
    Should Be Equal As Integers    ${months_apart}    1
