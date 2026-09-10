"""Load the repository's local API credential at CLI startup only."""
import os
from pathlib import Path

from dotenv import dotenv_values


def configure_api_key(env_path=None):
    """Preserve shell settings; accept the user's lowercase .env alias."""
    if "OPENAI_API_KEY" in os.environ:
        return bool(os.environ["OPENAI_API_KEY"])
    if "oai_api_key" in os.environ:
        key = os.environ["oai_api_key"]
    else:
        path = Path(env_path) if env_path is not None else Path(__file__).resolve().parents[2] / ".env"
        values = dotenv_values(path, interpolate=False)
        key = values.get("OPENAI_API_KEY") or values.get("oai_api_key")
    if key:
        os.environ["OPENAI_API_KEY"] = key
    return bool(key)
