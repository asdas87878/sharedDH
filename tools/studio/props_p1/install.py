"""Generate temporary HTTP Studio runner installers; does not change game source files."""
from pathlib import Path
import argparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path, nargs="?", default=Path("/tmp/ride-fish-props-p1"))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
base = Path(__file__).resolve().parent
sources = [
    ("Script", "P1Test", 'game:GetService("ServerScriptService")', "logger.server.luau"),
    ("LocalScript", "P1Driver", 'game:GetService("StarterPlayer").StarterPlayerScripts', "driver.client.luau"),
]
install = []
remove = []
for kind, name, parent, filename in sources:
    source = (base / filename).read_text()
    assert "]==]" not in source
    cleanup = f'local old = {parent}:FindFirstChild("{name}")\nif old then old:Destroy() end\n'
    remove.append("do\n" + cleanup + "end\n")
    install.append("do\n" + cleanup + f'local item = Instance.new("{kind}")\nitem.Name = "{name}"\nitem.Source = [==[{source}]==]\nitem.Parent = {parent}\nend\n')
(args.output / "install.luau").write_text("".join(remove + install) + 'return "props p1 test installed"\n')
(args.output / "remove.luau").write_text("".join(remove) + 'return "props p1 test removed"\n')
print(args.output / "install.luau")
print(args.output / "remove.luau")
