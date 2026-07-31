"""Poimii sijoitusasunnon perustiedot ilmoituslinkistä tai ladatusta tiedostosta Claudea käyttäen."""

import base64
import json
import mimetypes
import os

import anthropic

MODEL = "claude-opus-5"

SUPPORTED_IMAGE_TYPES = {"image/png", "image/jpeg", "image/webp", "image/gif"}

LISTING_SCHEMA = {
    "type": "object",
    "properties": {
        "purchase_price": {
            "anyOf": [{"type": "number"}, {"type": "null"}],
            "description": "Asunnon velaton myyntihinta euroina, jos ilmoituksessa mainittu.",
        },
        "monthly_rent": {
            "anyOf": [{"type": "number"}, {"type": "null"}],
            "description": "Kuukausivuokra euroina, jos ilmoituksessa mainittu tai arvioitu.",
        },
        "housing_fee": {
            "anyOf": [{"type": "number"}, {"type": "null"}],
            "description": "Kuukausittainen yhtiövastike euroina, jos ilmoituksessa mainittu.",
        },
        "notes": {
            "anyOf": [{"type": "string"}, {"type": "null"}],
            "description": "Lyhyt huomio siitä, mistä tiedot löytyivät tai mitkä arvot ovat epävarmoja.",
        },
    },
    "required": ["purchase_price", "monthly_rent", "housing_fee", "notes"],
    "additionalProperties": False,
}

INSTRUCTIONS = (
    "Poimi asuntoilmoituksesta seuraavat tiedot: velaton myyntihinta (purchase_price), "
    "kuukausivuokra jos ilmoitus sisältää vuokra-arvion tai kyseessä on vuokrailmoitus "
    "(monthly_rent), ja kuukausittainen yhtiövastike (housing_fee). Anna kaikki summat "
    "euroina ilman valuuttamerkkiä tai tuhaterottimia. Jos jotain tietoa ei löydy "
    "ilmoituksesta, käytä null-arvoa äläkä arvaa sitä."
)


class ListingExtractionError(RuntimeError):
    """Ilmoituksen tietojen poiminta epäonnistui."""


def _client() -> anthropic.Anthropic:
    if not os.environ.get("ANTHROPIC_API_KEY"):
        raise ListingExtractionError(
            "ANTHROPIC_API_KEY-ympäristömuuttujaa ei ole asetettu."
        )
    return anthropic.Anthropic()


def _parse_response(response) -> dict:
    if response.stop_reason == "refusal":
        raise ListingExtractionError("Claude ei pystynyt käsittelemään pyyntöä.")
    text = next((block.text for block in response.content if block.type == "text"), None)
    if not text:
        raise ListingExtractionError("Claudelta ei saatu jäsenneltyä vastausta.")
    return json.loads(text)


def _run(content, tools=None, max_tokens: int = 4096) -> dict:
    client = _client()
    kwargs = {
        "model": MODEL,
        "max_tokens": max_tokens,
        "output_config": {
            "effort": "low",
            "format": {"type": "json_schema", "schema": LISTING_SCHEMA},
        },
        "messages": [{"role": "user", "content": content}],
    }
    if tools:
        kwargs["tools"] = tools
    try:
        with client.messages.stream(**kwargs) as stream:
            response = stream.get_final_message()
    except anthropic.APIStatusError as exc:
        raise ListingExtractionError(f"Claude API -virhe: {exc.message}") from exc
    except anthropic.APIConnectionError as exc:
        raise ListingExtractionError("Yhteys Claude API:iin epäonnistui.") from exc
    return _parse_response(response)


def extract_from_url(url: str) -> dict:
    """Hakee ja poimii tiedot verkko-osoitteessa olevasta asuntoilmoituksesta."""
    content = f"{INSTRUCTIONS}\n\nIlmoituksen osoite: {url}"
    tools = [{"type": "web_fetch_20260209", "name": "web_fetch"}]
    return _run(content, tools=tools)


def extract_from_file(uploaded_file) -> dict:
    """Poimii tiedot ladatusta PDF- tai kuvatiedostosta (esim. ilmoituksen kuvakaappaus)."""
    file_bytes = uploaded_file.getvalue()
    mime_type = uploaded_file.type or mimetypes.guess_type(uploaded_file.name)[0] or ""
    encoded = base64.standard_b64encode(file_bytes).decode("utf-8")

    if mime_type == "application/pdf":
        content_block = {
            "type": "document",
            "source": {"type": "base64", "media_type": "application/pdf", "data": encoded},
        }
    elif mime_type in SUPPORTED_IMAGE_TYPES:
        content_block = {
            "type": "image",
            "source": {"type": "base64", "media_type": mime_type, "data": encoded},
        }
    else:
        raise ListingExtractionError(
            "Tiedostotyyppiä ei tueta. Lataa PDF- tai kuvatiedosto (PNG/JPEG/WebP)."
        )

    content = [content_block, {"type": "text", "text": INSTRUCTIONS}]
    return _run(content)
