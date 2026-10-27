using System.Numerics;
using System.Text;
using SoulsFormats;

// MsbDump: inspects and patches Elden Ring maps.
//   MsbDump <map.msb.dcx> <out.txt>
//       lists entity-ID'd regions, enemies, players and assets
//   MsbDump add-player <in.msb.dcx> <out.msb.dcx> <cloneEntityId> <newEntityId> <x> <y> <z> <rotY>
//       adds a player spawn point (copied from an existing one) usable as a WarpPlayer target
// Run from the output folder: the library looks for oo2core in the current directory.

static string V(Vector3 v) => $"({v.X:0.##}, {v.Y:0.##}, {v.Z:0.##})";

static string Dump(MSBE msb)
{
    var sb = new StringBuilder();
    sb.AppendLine("== Regions");
    foreach (var r in msb.Regions.GetEntries())
        if (r.EntityID != 0)
            sb.AppendLine($"{r.EntityID}\t{r.GetType().Name}\t{r.Name}\tpos={V(r.Position)} rot={V(r.Rotation)}\tshape={r.Shape?.GetType().Name}");

    sb.AppendLine("== Enemies");
    foreach (var e in msb.Parts.Enemies)
        if (e.EntityID != 0)
            sb.AppendLine($"{e.EntityID}\t{e.Name}\tmodel={e.ModelName}\tpos={V(e.Position)}\tnpc={e.NPCParamID} think={e.ThinkParamID}");

    sb.AppendLine("== Players");
    foreach (var p in msb.Parts.Players)
        sb.AppendLine($"{p.EntityID}\t{p.Name}\tpos={V(p.Position)} rot={V(p.Rotation)}");

    sb.AppendLine("== Assets");
    foreach (var a in msb.Parts.Assets)
        if (a.EntityID != 0)
            sb.AppendLine($"{a.EntityID}\t{a.Name}\tmodel={a.ModelName}\tpos={V(a.Position)}");

    // Every entity id in use (all part and region types), for picking free ids.
    sb.AppendLine("== AllEntityIDs");
    var all = msb.Parts.GetEntries().Select(p => p.EntityID).Concat(msb.Regions.GetEntries().Select(r => r.EntityID))
        .Where(id => id != 0).Distinct().OrderBy(id => id);
    sb.AppendLine(string.Join(" ", all));
    return sb.ToString();
}

static string Counts(MSBE msb) =>
    $"models={msb.Models.GetEntries().Count} events={msb.Events.GetEntries().Count} " +
    $"regions={msb.Regions.GetEntries().Count} routes={msb.Routes.GetEntries().Count} parts={msb.Parts.GetEntries().Count}";

if (args.Length == 5 && args[0] == "reg-rows")
{
    // reg-rows <regulation.bin> <ParamName> <paramdef.xml> <id,id,...>: those rows, every field as name=value
    // (one line per row: "id: f=v f=v ..."; missing rows are skipped)
    var bnd = SFUtil.DecryptERRegulation(args[1]);
    var param = PARAM.Read(bnd.Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == args[2]).Bytes.ToArray());
    param.ApplyParamdef(PARAMDEF.XmlDeserialize(args[3]));
    var byId = param.Rows.GroupBy(r => r.ID).ToDictionary(g => g.Key, g => g.First());
    foreach (int id in args[4].Split(',').Select(int.Parse))
        if (byId.TryGetValue(id, out var r))
            Console.WriteLine($"{id}: " + string.Join(" ", r.Cells.Where(c => !(c.Value is byte[]))
                .Select(c => $"{c.Def.InternalName}={Convert.ToString(c.Value, System.Globalization.CultureInfo.InvariantCulture)}")));
    return 0;
}

if (args.Length == 2 && args[0] == "reg-list")
{
    // reg-list <regulation.bin>: param file names
    foreach (var f in SFUtil.DecryptERRegulation(args[1]).Files) Console.WriteLine(Path.GetFileNameWithoutExtension(f.Name));
    return 0;
}

if (args.Length == 2 && args[0] == "check-ids")
{
    // check-ids <map.msb.dcx>: duplicate RegionIDs / player InstanceIDs (duplicates crash the game)
    var msb = MSBE.Read(args[1]);
    var dupRegions = msb.Regions.GetEntries().GroupBy(r => r.RegionID).Where(g => g.Count() > 1).ToList();
    var dupPlayers = msb.Parts.Players.GroupBy(p => p.InstanceID).Where(g => g.Count() > 1).ToList();
    var dupAssets = msb.Parts.Assets.GroupBy(a => (a.ModelName, a.InstanceID)).Where(g => g.Count() > 1).ToList();
    foreach (var g in dupAssets) Console.WriteLine($"duplicate asset InstanceID {g.Key}: {string.Join(", ", g.Select(a => a.Name))}");
    foreach (var g in dupRegions) Console.WriteLine($"duplicate RegionID {g.Key}: {string.Join(", ", g.Select(r => r.Name))}");
    foreach (var g in dupPlayers) Console.WriteLine($"duplicate player InstanceID {g.Key}: {string.Join(", ", g.Select(p => p.Name))}");
    Console.WriteLine(dupRegions.Count + dupPlayers.Count + dupAssets.Count == 0 ? "ids ok" : "ids DUPLICATED");
    return 0;
}

if (args.Length == 3 && args[0] == "props")
{
    // props <map.msb.dcx> <entityId>: every property of the region / part with that entity id
    var msb = MSBE.Read(args[1]);
    uint id = uint.Parse(args[2]);
    object e = (object)msb.Regions.GetEntries().FirstOrDefault(r => r.EntityID == id) ?? msb.Parts.GetEntries().First(p => p.EntityID == id);
    void Print(object o, string prefix, int depth)
    {
        foreach (var p in o.GetType().GetProperties().Where(p => p.GetIndexParameters().Length == 0))
        {
            object v = p.GetValue(o);
            if (v != null && depth < 2 && !(v is string) && !v.GetType().IsPrimitive && !(v is Vector3) && !v.GetType().IsEnum && !(v is System.Collections.IEnumerable))
                Print(v, prefix + p.Name + ".", depth + 1);
            else
                Console.WriteLine($"{prefix}{p.Name} = {(v is System.Collections.IEnumerable en && !(v is string) ? string.Join(",", en.Cast<object>()) : v)}");
        }
    }
    Console.WriteLine(e.GetType().FullName);
    Print(e, "", 0);
    return 0;
}

if (args.Length == 8 && args[0] == "add-asset")
{
    // add-asset <in.msb.dcx> <out.msb.dcx> <cloneEntityId> <newEntityId> <x> <y> <z>: a copy of an asset of
    // the map at another position (name / InstanceID: next free number of that model from 9500)
    var msb = MSBE.Read(args[1]);
    uint cloneId = uint.Parse(args[3]), newId = uint.Parse(args[4]);
    if (msb.Parts.GetEntries().Any(p => p.EntityID == newId) || msb.Regions.GetEntries().Any(r => r.EntityID == newId))
        throw new Exception($"entity {newId} already exists");
    string before = Counts(msb);
    var asset = (MSBE.Part.Asset)msb.Parts.Assets.First(a => a.EntityID == cloneId).DeepCopy();
    asset.EntityID = newId;
    int n = 9500;
    while (msb.Parts.Assets.Any(a => a.ModelName == asset.ModelName && (a.InstanceID == n || a.Name == $"{asset.ModelName}_{n}"))) n++;
    asset.InstanceID = n;
    asset.Name = $"{asset.ModelName}_{n}";
    asset.Position = new Vector3(float.Parse(args[5]), float.Parse(args[6]), float.Parse(args[7]));
    msb.Parts.Assets.Add(asset);
    msb.Write(args[2]);

    var check = MSBE.Read(args[2]);
    var added = check.Parts.Assets.Single(a => a.EntityID == newId);
    Console.WriteLine($"before: {before}");
    Console.WriteLine($"after:  {Counts(check)}");
    Console.WriteLine($"added asset {added.Name} entity={added.EntityID} pos={V(added.Position)}");
    static string[] Lines(string dump) => dump.Split('\n').TakeWhile(l => !l.StartsWith("== AllEntityIDs")).ToArray();
    var missing = Lines(Dump(MSBE.Read(args[1]))).Except(Lines(Dump(check))).ToList();
    if (missing.Count > 0)
        throw new Exception("vanilla entries changed:\n" + string.Join("\n", missing.Take(10)));
    Console.WriteLine("verified all vanilla entries unchanged");
    return 0;
}

if ((args.Length == 9 || args.Length == 10) && args[0] == "add-region")
{
    // add-region <in.msb.dcx> <out.msb.dcx> <cloneRegionEntityId> <newEntityId> <x> <y> <z> <radius>:
    // a sphere region (copied from an existing region of the map, for its other settings) usable with InArea
    var msb = MSBE.Read(args[1]);
    uint cloneId = uint.Parse(args[3]), newId = uint.Parse(args[4]);
    if (msb.Parts.GetEntries().Any(p => p.EntityID == newId) || msb.Regions.GetEntries().Any(r => r.EntityID == newId))
        throw new Exception($"entity {newId} already exists");
    string before = Counts(msb);
    var source = msb.Regions.Others.First(r => r.EntityID == cloneId);
    var region = (MSBE.Region.Other)source.DeepCopy();
    region.EntityID = newId;
    region.Name = $"BossReflections {newId}";
    region.Position = new Vector3(float.Parse(args[5]), float.Parse(args[6]), float.Parse(args[7]));
    region.Rotation = Vector3.Zero;
    // Optional 10th argument: height -> a vertical cylinder (position = its base) instead of a sphere.
    region.Shape = args.Length == 10
        ? new MSB.Shape.Cylinder(float.Parse(args[8]), float.Parse(args[9]))
        : new MSB.Shape.Sphere(float.Parse(args[8]));
    // RegionID must be unique in the map (a duplicate crashed the game loading Midra's map).
    region.RegionID = msb.Regions.GetEntries().Max(r => r.RegionID) + 1;
    msb.Regions.Others.Add(region);
    msb.Write(args[2]);

    var check = MSBE.Read(args[2]);
    var added = check.Regions.Others.Single(r => r.EntityID == newId);
    Console.WriteLine($"before: {before}");
    Console.WriteLine($"after:  {Counts(check)}");
    Console.WriteLine($"added region {added.Name} entity={added.EntityID} pos={V(added.Position)} " + (added.Shape is MSB.Shape.Cylinder cyl ? $"cylinder R={cyl.Radius} H={cyl.Height}" : $"sphere R={((MSB.Shape.Sphere)added.Shape).Radius}"));
    static string[] Lines(string dump) => dump.Split('\n').TakeWhile(l => !l.StartsWith("== AllEntityIDs")).ToArray();
    var missing = Lines(Dump(MSBE.Read(args[1]))).Except(Lines(Dump(check))).ToList();
    if (missing.Count > 0)
        throw new Exception("vanilla entries changed:\n" + string.Join("\n", missing.Take(10)));
    Console.WriteLine("verified all vanilla entries unchanged");
    return 0;
}

if ((args.Length == 9 || args.Length == 10) && args[0] == "add-player")
{
    var msb = MSBE.Read(args[1]);
    uint cloneId = uint.Parse(args[3]), newId = uint.Parse(args[4]);
    var pos = new Vector3(float.Parse(args[5]), float.Parse(args[6]), float.Parse(args[7]));
    float rotY = float.Parse(args[8]);

    if (msb.Parts.GetEntries().Any(p => p.EntityID == newId) || msb.Regions.GetEntries().Any(r => r.EntityID == newId))
        throw new Exception($"entity {newId} already exists");
    string before = Counts(msb);

    // Optional 10th argument: another map to take the player to copy from, for maps without any player
    // spawn point (e.g. m60_51_38); its c0000 model entry comes along if the map lacks it.
    var cloneMsb = args.Length == 10 ? MSBE.Read(args[9]) : msb;
    var source = cloneMsb.Parts.Players.First(p => p.EntityID == cloneId);
    var player = (MSBE.Part.Player)source.DeepCopy();
    if (!msb.Models.GetEntries().Any(m => m.Name == player.ModelName))
        msb.Models.Add(cloneMsb.Models.GetEntries().First(m => m.Name == player.ModelName).DeepCopy());
    player.EntityID = newId;
    player.Name = $"c0000_{9000 + newId % 1000}";
    for (int n = 9000 + (int)(newId % 1000); msb.Parts.GetEntries().Any(p => p.Name == player.Name); n++)
        player.Name = $"c0000_{n}";
    // InstanceID matches the name's number (c0000_9989 -> 9989), as in vanilla, instead of the clone's.
    player.InstanceID = int.Parse(player.Name.Substring(6));
    if (msb.Parts.Players.Any(p => p.InstanceID == player.InstanceID))
        throw new Exception($"player instance id {player.InstanceID} already exists");
    player.Position = pos;
    player.Rotation = new Vector3(0, rotY, 0);
    if (msb.Parts.GetEntries().Any(p => p.Name == player.Name))
        throw new Exception($"part name {player.Name} already exists");
    msb.Parts.Players.Add(player);
    msb.Write(args[2]);

    // Re-read the written map: everything vanilla must still be there, plus exactly one new player.
    var check = MSBE.Read(args[2]);
    var added = check.Parts.Players.Single(p => p.EntityID == newId);
    Console.WriteLine($"before: {before}");
    Console.WriteLine($"after:  {Counts(check)}");
    Console.WriteLine($"added {added.Name} entity={added.EntityID} pos={V(added.Position)} rot={V(added.Rotation)}");
    // Compare the per-entry lines; the "all entity ids" line is compared as sets (it gains the new id).
    static (string[] Lines, string[] Ids) Split(string dump)
    {
        var lines = dump.Split('\n');
        int i = Array.IndexOf(lines, "== AllEntityIDs\r") is var r && r >= 0 ? r : Array.IndexOf(lines, "== AllEntityIDs");
        return (lines.Take(i).ToArray(), lines[i + 1].Trim().Split(' '));
    }
    var vanilla = Split(Dump(MSBE.Read(args[1])));
    var patched = Split(Dump(check));
    var missing = vanilla.Lines.Except(patched.Lines).Concat(vanilla.Ids.Except(patched.Ids)).ToList();
    if (missing.Count > 0)
        throw new Exception("vanilla entries changed:\n" + string.Join("\n", missing.Take(10)));
    Console.WriteLine("verified all vanilla entries unchanged");
    return 0;
}

if (args.Length >= 5 && args[0] == "copy-entities")
{
    // copy-entities <src.msb.dcx> <dst.msb.dcx> <out.msb.dcx> <entityId...>
    // Copies parts / regions with the given entity ids from another variant of the same map (e.g. a boss
    // that m61_44_45_10 lacks but m61_44_45_00 has), with the models they need.
    var src = MSBE.Read(args[1]);
    var dst = MSBE.Read(args[2]);
    string before = Counts(dst);
    var dstNames = new HashSet<string>(dst.Parts.GetEntries().Select(p => p.Name));
    foreach (uint id in args.Skip(4).Select(uint.Parse))
    {
        if (dst.Parts.GetEntries().Any(p => p.EntityID == id) || dst.Regions.GetEntries().Any(r => r.EntityID == id))
            throw new Exception($"entity {id} already exists in the destination");
        var part = src.Parts.GetEntries().FirstOrDefault(p => p.EntityID == id);
        if (part != null)
        {
            var copy = part.DeepCopy();
            if (!dst.Models.GetEntries().Any(m => m.Name == copy.ModelName))
                dst.Models.Add(src.Models.GetEntries().First(m => m.Name == copy.ModelName).DeepCopy());
            for (int n = 0; dstNames.Contains(copy.Name); n++)
                copy.Name = $"{part.Name}_r{n}";
            dstNames.Add(copy.Name);
            if (copy is MSBE.Part.Enemy e && !string.IsNullOrEmpty(e.CollisionPartName) && !dstNames.Contains(e.CollisionPartName))
                throw new Exception($"{part.Name}: collision part {e.CollisionPartName} is missing in the destination");
            dst.Parts.Add(copy);
            Console.WriteLine($"copied part {copy.Name} entity={id} model={copy.ModelName} pos={V(copy.Position)}");
            continue;
        }
        var region = src.Regions.GetEntries().FirstOrDefault(r => r.EntityID == id) ?? throw new Exception($"entity {id} not found in the source");
        var regionCopy = region.DeepCopy();
        // RegionID must be unique in the map (a duplicate crashes the game on load).
        regionCopy.RegionID = dst.Regions.GetEntries().Max(r => r.RegionID) + 1;
        dst.Regions.Add(regionCopy);
        Console.WriteLine($"copied region {region.Name} entity={id} pos={V(region.Position)}");
    }
    dst.Write(args[3]);

    var check = MSBE.Read(args[3]);
    Console.WriteLine($"before: {before}");
    Console.WriteLine($"after:  {Counts(check)}");
    foreach (uint id in args.Skip(4).Select(uint.Parse))
        if (!check.Parts.GetEntries().Any(p => p.EntityID == id) && !check.Regions.GetEntries().Any(r => r.EntityID == id))
            throw new Exception($"entity {id} missing after writing");
    var vanillaLines = Dump(MSBE.Read(args[2])).Split('\n').TakeWhile(l => !l.StartsWith("== AllEntityIDs"));
    var patchedLines = Dump(check).Split('\n');
    var missing = vanillaLines.Except(patchedLines).ToList();
    if (missing.Count > 0)
        throw new Exception("vanilla entries changed:\n" + string.Join("\n", missing.Take(10)));
    Console.WriteLine("verified all vanilla entries unchanged");
    return 0;
}

if (args.Length == 6 && args[0] == "reg-find")
{
    // reg-find <regulation.bin> <ParamName> <paramdef.xml> <field> <value>: rows whose field has the value,
    // with their non-zero fields
    var bnd = SFUtil.DecryptERRegulation(args[1]);
    var param = PARAM.Read(bnd.Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == args[2]).Bytes.ToArray());
    param.ApplyParamdef(PARAMDEF.XmlDeserialize(args[3]));
    foreach (var r in param.Rows.Where(r => (args[4] == "ID" ? r.ID.ToString() : Convert.ToString(r[args[4]].Value, System.Globalization.CultureInfo.InvariantCulture)) == args[5]))
        Console.WriteLine($"{r.ID}: " + string.Join(" ", r.Cells
            .Where(c => Convert.ToString(c.Value, System.Globalization.CultureInfo.InvariantCulture) is var s && s != "0" && s != "False")
            .Select(c => $"{c.Def.InternalName}={c.Value}")));
    return 0;
}

if (args.Length == 6 && args[0] == "reg-add-rows")
{
    // reg-add-rows <in regulation.bin> <out regulation.bin> <ParamName> <paramdef.xml> <rows.xml>
    // Adds rows given as XML attributes. copyFrom="<id>" starts from a copy of that vanilla row,
    // otherwise unlisted fields get the paramdef defaults.
    var bnd = SFUtil.DecryptERRegulation(args[1]);
    string paramName = args[3];
    var file = bnd.Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == paramName);
    var def = PARAMDEF.XmlDeserialize(args[4]);
    var param = PARAM.Read(file.Bytes.ToArray());
    param.ApplyParamdef(def);
    int before = param.Rows.Count;

    var rows = System.Xml.Linq.XDocument.Load(args[5]).Root.Elements("row").ToList();
    foreach (var x in rows)
    {
        int id = int.Parse(x.Attribute("id").Value);
        if (param.Rows.Any(r => r.ID == id))
            throw new Exception($"{paramName} row {id} already exists");
        string name = x.Attribute("paramdexName")?.Value ?? "";
        var copyFrom = x.Attribute("copyFrom");
        var row = copyFrom == null
            ? new PARAM.Row(id, name, def)
            : new PARAM.Row(param.Rows.First(r => r.ID == int.Parse(copyFrom.Value))) { ID = id, Name = name };
        foreach (var a in x.Attributes().Where(a => a.Name != "id" && a.Name != "paramdexName" && a.Name != "copyFrom"))
        {
            var cell = row[a.Name.LocalName] ?? throw new Exception($"unknown field {a.Name}");
            cell.Value = Convert.ChangeType(a.Value, cell.Value.GetType(), System.Globalization.CultureInfo.InvariantCulture);
        }
        param.Rows.Add(row);
    }
    param.Rows = param.Rows.OrderBy(r => r.ID).ToList();
    file.Bytes = param.Write();
    SFUtil.EncryptERRegulation(args[2], bnd);

    // Check: re-read the written regulation; vanilla rows must be identical, ours present.
    var vanilla = PARAM.Read(SFUtil.DecryptERRegulation(args[1]).Files.First(f => f.Name == file.Name).Bytes.ToArray());
    var written = PARAM.Read(SFUtil.DecryptERRegulation(args[2]).Files.First(f => f.Name == file.Name).Bytes.ToArray());
    vanilla.ApplyParamdef(def);
    written.ApplyParamdef(def);
    var byId = written.Rows.ToDictionary(r => r.ID);
    static string Key(PARAM.Row r) => string.Join("|", r.Cells.Select(c => c.Value is byte[] b ? Convert.ToHexString(b) : Convert.ToString(c.Value, System.Globalization.CultureInfo.InvariantCulture)));
    foreach (var r in vanilla.Rows)
        if (!byId.TryGetValue(r.ID, out var w) || Key(w) != Key(r))
            throw new Exception($"vanilla row {r.ID} changed");
    foreach (var x in rows)
    {
        var w = byId[int.Parse(x.Attribute("id").Value)];
        var src = x.Attribute("copyFrom") is { } cf ? byId[int.Parse(cf.Value)] : null;
        // Report every field that differs from the copied row (or every set field without copyFrom).
        foreach (var c in w.Cells)
        {
            string val = Convert.ToString(c.Value, System.Globalization.CultureInfo.InvariantCulture);
            if (src == null ? x.Attribute(c.Def.InternalName) != null
                            : Convert.ToString(src[c.Def.InternalName].Value, System.Globalization.CultureInfo.InvariantCulture) != val)
                Console.WriteLine($"  {w.ID}.{c.Def.InternalName} = {val}" + (src == null ? "" : $" (row {src.ID}: {src[c.Def.InternalName].Value})"));
        }
    }
    Console.WriteLine($"{paramName}: {before} -> {written.Rows.Count} rows, vanilla rows unchanged");
    return 0;
}

if (args.Length == 6 && args[0] == "inside")
{
    // inside <map.msb.dcx> <regionEntityId> <x> <y> <z>: shape of a region and whether the point is in it
    var msb = MSBE.Read(args[1]);
    var p = new Vector3(float.Parse(args[3]), float.Parse(args[4]), float.Parse(args[5]));
    var region = msb.Regions.GetEntries().First(r => r.EntityID == uint.Parse(args[2]));
    var regions = new List<MSBE.Region> { region };
    if (region.Shape is MSB.Shape.Composite comp)
    {
        Console.WriteLine($"{region.Name}: composite of {string.Join(", ", comp.Children.Where(c => c.RegionName != null).Select(c => c.RegionName))}");
        regions = comp.Children.Where(c => c.RegionName != null)
            .Select(c => (MSBE.Region)msb.Regions.GetEntries().First(r => r.Name == c.RegionName)).ToList();
    }
    foreach (var r in regions)
    {
        // Point in the region's local frame (FromSoft rotations are Y-up, degrees).
        var rot = Matrix4x4.CreateRotationX(r.Rotation.X * MathF.PI / 180)
            * Matrix4x4.CreateRotationZ(r.Rotation.Z * MathF.PI / 180)
            * Matrix4x4.CreateRotationY(r.Rotation.Y * MathF.PI / 180);
        Matrix4x4.Invert(rot, out var inv);
        var l = Vector3.Transform(p - r.Position, inv);
        string shape = r.Shape switch
        {
            MSB.Shape.Box b => $"box W={b.Width} D={b.Depth} H={b.Height} -> {(MathF.Abs(l.X) <= b.Width / 2 && MathF.Abs(l.Z) <= b.Depth / 2 && l.Y >= 0 && l.Y <= b.Height ? "INSIDE" : "outside")}",
            MSB.Shape.Sphere s => $"sphere R={s.Radius} -> {(l.Length() <= s.Radius ? "INSIDE" : "outside")}",
            MSB.Shape.Cylinder c => $"cylinder R={c.Radius} H={c.Height} -> {(new Vector2(l.X, l.Z).Length() <= c.Radius && l.Y >= 0 && l.Y <= c.Height ? "INSIDE" : "outside")}",
            _ => r.Shape?.GetType().Name,
        };
        Console.WriteLine($"{r.Name} pos={V(r.Position)} rot={V(r.Rotation)} local={V(l)} {shape}");
    }
    return 0;
}

if (args.Length == 2)
{
    File.WriteAllText(args[1], Dump(MSBE.Read(args[0])));
    Console.WriteLine("ok");
    return 0;
}

Console.WriteLine("Usage: MsbDump <map.msb.dcx> <out.txt>");
Console.WriteLine("       MsbDump add-player <in.msb.dcx> <out.msb.dcx> <cloneEntityId> <newEntityId> <x> <y> <z> <rotY>");
return 1;
