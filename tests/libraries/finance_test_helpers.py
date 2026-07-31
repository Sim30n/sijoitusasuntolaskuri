"""Small plain-Python helpers for system-test assertions (called via Robot's Evaluate keyword).

Kept as plain functions rather than robot keywords/regex-in-.robot-text because escaping
regex backslashes inside Robot Framework argument text is its own source of bugs.
"""
import re

_EURO_AMOUNT_RE = re.compile(r"(-?[\d  .,]+)\s*€")


def parse_euro_amount(text):
    """Extracts a euro amount from an st.metric's full text, e.g. turns
    "Kokonaisvoitto (28.07.2031)\\n\\n18,086 €" into 18086.0.
    """
    match = _EURO_AMOUNT_RE.search(text)
    if not match:
        raise ValueError(f"No euro amount found in: {text!r}")
    cleaned = match.group(1).replace(" ", "").replace(",", "").replace(" ", "").strip()
    return float(cleaned)


_PERCENT_RE = re.compile(r"(-?[\d.,]+)\s*%")


def parse_percent(text):
    """Extracts a percentage from an st.metric's full text, e.g. turns "ROE (...)\\n\\n57.3 %" into 57.3."""
    match = _PERCENT_RE.search(text)
    if not match:
        raise ValueError(f"No percentage found in: {text!r}")
    return float(match.group(1).replace(",", "."))
