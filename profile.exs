json = File.read!("/Users/Adz/Projects/jxon/bench/data/govtrack.json")
JxonSlim.parse(json, SlimHandler, 0, [])
