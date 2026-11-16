"""The lighting tests of the look pass (docs/reference/look-lighting.md, section 5): writes the plan that
tools/studio/look_shots.py runs. Each variant is today's Config.Look with a few numbers changed, put on the open place in
Edit mode with Look.apply (nothing in src/ changes), then pictured from three fixed spots.
usage: python tools/studio/look_tests.py <plan.json> <variant>[@quality] ... [--spots tank,swatch]    e.g. ours@21 ours@1 sunA
       python tools/studio/look_tests.py <plan.json> --restore                   our look, Realistic, level 21, swatch gone
Pictures are named <variant><quality>_<spot>.jpg. The last step of every plan puts our own look back.
"""
import json
import sys

SPOTS = {
    "spawn": ([3000, 9, -124], [3000, 14, -300]),  # the hub as a player first sees it
    "lane": ([3010, 26, 70], [3000, 16, 420]),  # down the lane over the water: the lit wall and the shaded one
    "tank": ([3112, 14, -196], [3168, 8, -236]),  # plot 7's tank: its lit front, its shaded side, the swatch
    "swatch": ([3141, 9, -189], [3130, 3.5, -200]),  # the swatch from its shaded side: its top in the sun, two sides in shade
}
SWATCH = [3130, 3.5, -200]  # a 6-stud block of 83, 214, 100 (the measure of 2026-11-12): top, sunlit side, shaded side

WARM = {"SunR": 215, "SunG": 190, "SunB": 135}
VARIANTS = {
    "ours": {},
    "sunA": dict(WARM),  # test 2: the recipe's warm sun
    "sunB": {"SunR": 232, "SunG": 222, "SunB": 160},  # test 2: a paler one
    "recipe": {  # test 3: the shared recipe, whole (our sun angle kept, so the same faces are lit)
        **WARM, "Brightness": 2.5, "AmbientR": 200, "AmbientG": 160, "AmbientB": 225, "OutdoorR": 125, "OutdoorG": 100,
        "OutdoorB": 150, "EnvDiffuse": 0.4, "EnvSpecular": 0.5, "ShadowSoftness": 0.2, "Exposure": 0,
        "ColourBrightness": 0.05, "Contrast": 0.1, "Saturation": 0.15, "TintR": 255, "TintG": 255, "TintB": 255,
        "BloomIntensity": 0, "_style": "Soft", "_fog": [200, 170, 250, 0, 2500],
    },
    "soft": {"_style": "Soft"},  # test 4: ours, Soft
    "lilacA": {**WARM, "AmbientR": 200, "AmbientG": 160, "AmbientB": 225},  # test 5: a lilac shade, the recipe's
    "lilacB": {**WARM, "AmbientR": 160, "AmbientG": 145, "AmbientB": 180},  # test 5: halfway
    "shadow": {"ShadowSoftness": 0.2},  # test 8
    "shineA": {"EnvSpecular": 0.5},  # test 7: how much the sky shows in the floor
    "shineB": {"EnvSpecular": 0.25},
    "spec0": {"EnvSpecular": 0},  # to find where the blue on up-facing things comes from
    "diff0": {"EnvDiffuse": 0},
    "pickA": {**WARM, "ShadowSoftness": 0.2, "EnvSpecular": 0.25},  # what the tests point to, together
    "pickB": {**WARM, "ShadowSoftness": 0.2, "EnvSpecular": 0.25, "AmbientR": 160, "AmbientG": 145, "AmbientB": 180},  # and a little lilac
}

APPLY = r'''
local OVER = %s
local STYLE = "%s"
local QUALITY = %d
local FOG = %s
local Lighting = game:GetService("Lighting")
local RS = game:GetService("ReplicatedStorage")
local function fresh(m)
	local c = m:Clone()
	c.Name = m.Name .. "_LookTest"
	c.Parent = m.Parent
	local ok, r = pcall(require, c)
	c:Destroy()
	if not ok then error(r) end
	return r
end
local Config = fresh(RS.Shared.Config)
local Look = fresh(RS.Shared.Look)
local v = table.clone(Config.Look)
for k, x in OVER do v[k] = x end
Look.apply(Lighting, v)
Lighting.LightingStyle = Enum.LightingStyle[STYLE]
settings().Rendering.EditQualityLevel = (Enum.QualityLevel :: any)[string.format("Level%%02d", QUALITY)]
local hold = workspace:FindFirstChild("ClaudeLookSwatch")
if not hold then
	hold = Instance.new("Model")
	hold.Name = "ClaudeLookSwatch"
	hold.Parent = workspace
end
if not hold:FindFirstChild("Swatch") then
	hold:ClearAllChildren()
	local p = Instance.new("Part")
	p.Name = "Swatch"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = Vector3.new(6, 6, 6)
	p.Position = Vector3.new(%d, %s, %d)
	p.Color = Color3.fromRGB(83, 214, 100)
	p.Parent = hold
end
if hold:GetAttribute("FogEnd") == nil then
	hold:SetAttribute("FogEnd", Lighting.FogEnd)
	hold:SetAttribute("FogStart", Lighting.FogStart)
	hold:SetAttribute("FogColor", Lighting.FogColor)
end
local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or hold:FindFirstChildOfClass("Atmosphere")
if FOG then
	if atmo then atmo.Parent = hold end
	Lighting.FogColor = Color3.fromRGB(FOG[1], FOG[2], FOG[3])
	Lighting.FogStart = FOG[4]
	Lighting.FogEnd = FOG[5]
else
	if atmo then atmo.Parent = Lighting end
	Lighting.FogColor = hold:GetAttribute("FogColor")
	Lighting.FogStart = hold:GetAttribute("FogStart")
	Lighting.FogEnd = hold:GetAttribute("FogEnd")
end
return string.format("%%s at level %%d: ambient %%s, sun %%s, brightness %%s, style %%s, fov %%s", "%s", QUALITY,
	tostring(Lighting.Ambient), tostring(Lighting.ColorShift_Top), tostring(Lighting.Brightness), tostring(Lighting.LightingStyle),
	tostring(workspace.CurrentCamera.FieldOfView))
'''

RESTORE = r'''
local Lighting = game:GetService("Lighting")
local hold = workspace:FindFirstChild("ClaudeLookSwatch")
if hold then
	local atmo = hold:FindFirstChildOfClass("Atmosphere")
	if atmo then atmo.Parent = Lighting end
	if hold:GetAttribute("FogEnd") ~= nil then
		Lighting.FogColor = hold:GetAttribute("FogColor")
		Lighting.FogStart = hold:GetAttribute("FogStart")
		Lighting.FogEnd = hold:GetAttribute("FogEnd")
	end
	hold:Destroy()
end
settings().Rendering.EditQualityLevel = Enum.QualityLevel.Level21
return "swatch gone, fog and Atmosphere back, level 21"
'''


def lua(value):
    if isinstance(value, dict):
        return "{" + ", ".join("%s = %s" % (k, lua(x)) for k, x in value.items()) + "}"
    if isinstance(value, (list, tuple)):
        return "{" + ", ".join(lua(x) for x in value) + "}"
    if value is None or value is False:
        return "false"
    return repr(value)


def apply(name, quality):
    over = dict(VARIANTS[name])
    style = over.pop("_style", "Realistic")
    fog = over.pop("_fog", None)
    return APPLY % (lua(over), style, quality, lua(fog), SWATCH[0], SWATCH[1], SWATCH[2], name)


def main():
    out = sys.argv[1]
    plan = []
    if "--restore" in sys.argv:
        plan = [{"luau": RESTORE}, {"file": "tools/studio/look_install.luau"}]
    else:
        spots = SPOTS
        if "--shots" in sys.argv:  # other spots, from a file: {"name": [[cam], [look at]], ...}
            i = sys.argv.index("--shots")
            spots = {name: tuple(v) for name, v in json.load(open(sys.argv[i + 1], encoding="utf-8")).items()}
            del sys.argv[i:i + 2]
        if "--spots" in sys.argv:
            i = sys.argv.index("--spots")
            spots = {name: SPOTS[name] for name in sys.argv[i + 1].split(",")}
            del sys.argv[i:i + 2]
        for item in sys.argv[2:]:
            name, _, quality = item.partition("@")
            quality = int(quality or 21)
            plan.append({"luau": apply(name, quality)})
            plan.append({"wait": 2.5})
            for spot, (cam, at) in spots.items():
                plan.append({"shot": "%s%02d_%s" % (name, quality, spot), "cam": cam, "at": at})
                plan.append({"wait": 0.4})
        plan.append({"luau": apply("ours", 21)})
    json.dump(plan, open(out, "w", encoding="utf-8"), indent=1)
    print(len(plan), "steps")


main()
