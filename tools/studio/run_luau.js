// Runs a Luau file in Studio (Edit mode) through the direct client, optionally replacing `local NAME = ...` lines first.
// usage: node tools/studio/run_luau.js <studio_id> <file.luau> [NAME=luau-value ...]
//   e.g. node tools/studio/run_luau.js <id> tools/studio/depth_look_test.luau 'LOOK="B"' 'STOP="Trench"'
// The direct client is C:\Users\blast\RpgGame\tools\studio\studio_mcp.py (the app's connector chokes on long code).
// On Linux (Hugo's PC) Roblox's MCP proxy hangs Studio under Wine, so the file goes through the studio runner instead
// (~/Projects/studio-runner/studio-run.mjs, a plugin that polls a local server like Rojo; STUDIO_RUNNER overrides the
// path). There <studio_id> is ignored and may be left out.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

if (process.platform !== "win32") {
	const argv = process.argv.slice(2);
	if (argv[0] && !/\.luau?$/.test(argv[0])) argv.shift(); // the studio id: only one Studio here
	const runner = process.env.STUDIO_RUNNER || path.join(require("os").homedir(), "Projects", "studio-runner", "studio-run.mjs");
	const { spawnSync } = require("child_process");
	process.exit(spawnSync(process.execPath, [runner, ...argv], { stdio: "inherit" }).status ?? 1);
}

const [studioId, file, ...sets] = process.argv.slice(2);
let code = fs.readFileSync(file, "utf8");
for (const set of sets) {
	const at = set.indexOf("=");
	const name = set.slice(0, at);
	const value = set.slice(at + 1);
	const line = new RegExp(`^local ${name} = .*$`, "m");
	if (!line.test(code)) throw new Error(`no "local ${name} = " line in ${file}`);
	code = code.replace(line, `local ${name} = ${value}`);
}
const args = path.join(__dirname, "..", "..", ".tmp_run_args.json");
fs.writeFileSync(args, JSON.stringify({ studio_id: studioId, datamodel_type: "Edit", code }));
try {
	const out = execFileSync("python", ["C:/Users/blast/RpgGame/tools/studio/studio_mcp.py", "call", "execute_luau", "@" + args, "180"], {
		encoding: "utf8",
	});
	const result = out.split("\n").find((l) => l.startsWith('{"content"'));
	if (!result) {
		console.log(out);
		process.exit(1);
	}
	const parsed = JSON.parse(result);
	console.log(parsed.content.map((c) => c.text).join("\n"));
	if (parsed.isError) process.exit(1);
} finally {
	fs.unlinkSync(args);
}
