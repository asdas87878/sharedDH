"""Install (or remove with --remove) the ZZSizeMock LocalScript in Studio's Edit mode through studio-runner (task u2)."""
import subprocess, sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
RUN = Path.home() / "Projects/studio-runner/studio-run.mjs"
if "--remove" in sys.argv:
    args = ["REMOVE=true"]
else:
    src = (HERE / "mock_client.luau").read_text()
    assert "]=====]" not in src
    args = ["SOURCE=[=====[" + src + "]=====]"]
subprocess.run(["node", str(RUN), str(HERE / "install.luau"), *args], check=True)
