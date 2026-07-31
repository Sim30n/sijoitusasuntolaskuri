"""Robot Framework keyword library for testing listing_extractor.py without network access.

Stubs the `anthropic.Anthropic` client that listing_extractor._client() constructs,
so extract_from_url()/extract_from_file() can be exercised end to end (schema
handling, error mapping, mime-type routing) offline and deterministically.
"""
import json
import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import anthropic

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import listing_extractor  # noqa: E402


class _FakeTextBlock:
    def __init__(self, text):
        self.type = "text"
        self.text = text


class _FakeResponse:
    def __init__(self, payload=None, stop_reason="end_turn", empty_content=False):
        self.stop_reason = stop_reason
        self.content = [] if empty_content else [_FakeTextBlock(json.dumps(payload or {}))]


class _FakeStream:
    def __init__(self, response):
        self._response = response

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def get_final_message(self):
        return self._response


class _FakeUploadedFile:
    """Mimics the subset of Streamlit's UploadedFile that listing_extractor.extract_from_file uses."""

    def __init__(self, path, mime_type):
        self._bytes = Path(path).read_bytes()
        self.type = mime_type
        self.name = Path(path).name

    def getvalue(self):
        return self._bytes


class ListingExtractorTestLibrary:
    """Keywords to stub the Anthropic API and call listing_extractor with it."""

    ROBOT_LIBRARY_SCOPE = "TEST"

    def __init__(self):
        self._patchers = []
        self._env_snapshot = dict(listing_extractor.os.environ)
        self.last_stream_kwargs = None

    def set_anthropic_api_key(self, key="sk-ant-test-stub-key"):
        listing_extractor.os.environ["ANTHROPIC_API_KEY"] = key

    def unset_anthropic_api_key(self):
        listing_extractor.os.environ.pop("ANTHROPIC_API_KEY", None)

    def restore_environment(self):
        listing_extractor.os.environ.clear()
        listing_extractor.os.environ.update(self._env_snapshot)
        for patcher in self._patchers:
            patcher.stop()
        self._patchers = []

    def stub_anthropic_success(self, payload):
        """Makes the next Anthropic call return `payload` as the model's structured JSON output."""
        self._install_client_stub(response=_FakeResponse(payload=payload))

    def stub_anthropic_refusal(self):
        self._install_client_stub(response=_FakeResponse(stop_reason="refusal"))

    def stub_anthropic_empty_response(self):
        self._install_client_stub(response=_FakeResponse(empty_content=True))

    def stub_anthropic_status_error(self, message="rate limited"):
        error = anthropic.APIStatusError(
            message=message,
            response=MagicMock(status_code=429, request=MagicMock()),
            body={"error": {"message": message}},
        )
        self._install_client_stub(error=error)

    def stub_anthropic_connection_error(self):
        error = anthropic.APIConnectionError(request=MagicMock())
        self._install_client_stub(error=error)

    def _install_client_stub(self, response=None, error=None):
        fake_client = MagicMock()
        stream_cm = MagicMock()
        if error is not None:
            stream_cm.__enter__.side_effect = error
        else:
            stream_cm.__enter__.return_value = _FakeStream(response).__enter__()
        fake_client.messages.stream.side_effect = self._record_and_return(stream_cm)

        patcher = patch.object(listing_extractor.anthropic, "Anthropic", return_value=fake_client)
        patcher.start()
        self._patchers.append(patcher)

    def _record_and_return(self, stream_cm):
        def _stream(**kwargs):
            self.last_stream_kwargs = kwargs
            return stream_cm
        return _stream

    def extract_from_url(self, url):
        return listing_extractor.extract_from_url(url)

    def extract_from_file(self, path, mime_type):
        uploaded_file = _FakeUploadedFile(path, mime_type)
        return listing_extractor.extract_from_file(uploaded_file)

    def get_last_request_used_web_fetch_tool(self):
        tools = (self.last_stream_kwargs or {}).get("tools") or []
        return any(tool.get("name") == "web_fetch" for tool in tools)
