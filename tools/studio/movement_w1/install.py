"""Generate temporary HTTP Studio runner installers; does not change game source files."""
from pathlib import Path
import argparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path, nargs="?", default=Path("/tmp/ride-fish-movement"))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
base = Path(__file__).resolve().parent
sources = [
    ("Script", "W1Test", 'game:GetService("ServerScriptService")', "logger.server.luau"),
    ("LocalScript", "W1Driver", 'game:GetService("StarterPlayer").StarterPlayerScripts', "driver.client.luau"),
]
install = []
remove = []
for kind, name, parent, filename in sources:
    source = (base / filename).read_text()
    assert "]==]" not in source
    cleanup = f'local old = {parent}:FindFirstChild("{name}")\nif old then old:Destroy() end\n'
    remove.append("do\n" + cleanup + "end\n")
    install.append("do\n" + cleanup + f'local item = Instance.new("{kind}")\nitem.Name = "{name}"\nitem.Source = [==[{source}]==]\nitem.Parent = {parent}\nend\n')
# Also remove the earlier experimental clone, if an interrupted draft run left one behind.
remove.append('local lib = game:GetService("StarterPlayer").StarterPlayerScripts.Client.Lib\nlocal old = lib:FindFirstChild("W1Course")\nif old then old:Destroy() end\n')
(args.output / "install.luau").write_text("".join(remove + install) + 'return "movement test installed"\n')
(args.output / "remove.luau").write_text("".join(remove) + 'return "movement test removed"\n')
print(args.output / "install.luau")
print(args.output / "remove.luau")
