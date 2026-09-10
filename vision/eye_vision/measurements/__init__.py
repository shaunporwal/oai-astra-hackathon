"""Pure image measurement modules; no HTTP, API credentials or camera dependencies."""
from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class Measurement:
    target_id: str
    name: str
    unit: str
    value: float | None
    status: str
    reason: str
    method: str
    source: str = 'local_image_analysis'
    validated: bool = False

    def to_dict(self):
        return asdict(self)
