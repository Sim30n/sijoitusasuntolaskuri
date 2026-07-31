"""Small helpers for system tests that need to launch the real Streamlit app.

Kept out of .robot files because picking a free TCP port and polling a health
endpoint are easier to express (and unit-test) as plain Python.
"""
import socket
import time
import urllib.error
import urllib.request


class AppServerLibrary:

    def get_free_port(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.bind(("127.0.0.1", 0))
            return sock.getsockname()[1]

    def wait_for_health(self, url, timeout=40, interval=0.5):
        deadline = time.time() + float(timeout)
        last_error = None
        while time.time() < deadline:
            try:
                with urllib.request.urlopen(url, timeout=2) as response:
                    if response.status == 200:
                        return True
            except (urllib.error.URLError, ConnectionError, OSError) as exc:
                last_error = exc
            time.sleep(float(interval))
        raise AssertionError(f"App did not become healthy at {url} within {timeout}s: {last_error}")
