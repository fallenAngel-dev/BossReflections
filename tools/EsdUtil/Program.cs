using System.Text;
using SoulsFormats;
using ESDLang.Adapter;
using ESDLang.Doc;
using ESDLang.EzSemble;

// EsdUtil: dumps Elden Ring talk ESDs to readable text.
// Usage: EsdUtil dump <file.talkesdbnd.dcx> <outdir>

static EzSembleContext LoadContext()
{
    string doc = Path.Combine(AppContext.BaseDirectory, "ESDScriptingDocumentation_Talk.json");
    var ctx = new EzSembleContext
    {
        Doc = ESDDocumentation.DeserializeFromFile(doc, new ESDDocumentation.DocOptions { Game = "er" }),
    };
    ctx.PopulateNamesFromDoc();
    return ctx;
}

static ESDL ReadEsd(byte[] bytes, EzSembleContext ctx)
{
    var esd = new ESDL();
    esd.ReadWithContext(new BinaryReaderEx(false, bytes), ctx);
    return esd;
}

static void DumpCondition(StringBuilder sb, ESDL.Condition c, string indent)
{
    string target = c.TargetState.HasValue ? $" -> {c.TargetState}" : "";
    sb.AppendLine($"{indent}if {c.Evaluator}{target}");
    if (!string.IsNullOrWhiteSpace(c.PassScript))
        sb.AppendLine($"{indent}    pass: {c.PassScript.Trim().Replace("\n", "\n" + indent + "          ")}");
    foreach (var sub in c.Subconditions)
        DumpCondition(sb, sub, indent + "    ");
}

static string Dump(ESDL esd)
{
    var sb = new StringBuilder();
    foreach (var (groupId, states) in esd.StateGroups.OrderBy(g => g.Key))
    {
        sb.AppendLine($"===== StateGroup {groupId}");
        foreach (var (stateId, s) in states.OrderBy(s => s.Key))
        {
            sb.AppendLine($"--- State {groupId}:{stateId}");
            if (!string.IsNullOrWhiteSpace(s.EntryScript)) sb.AppendLine("  entry:\n    " + s.EntryScript.Trim().Replace("\n", "\n    "));
            if (!string.IsNullOrWhiteSpace(s.ExitScript)) sb.AppendLine("  exit:\n    " + s.ExitScript.Trim().Replace("\n", "\n    "));
            if (!string.IsNullOrWhiteSpace(s.WhileScript)) sb.AppendLine("  while:\n    " + s.WhileScript.Trim().Replace("\n", "\n    "));
            foreach (var c in s.Conditions)
                DumpCondition(sb, c, "  ");
        }
        sb.AppendLine();
    }
    return sb.ToString();
}

if (args.Length >= 3 && args[0] == "dump")
{
    var ctx = LoadContext();
    var bnd = BND4.Read(args[1]);
    Directory.CreateDirectory(args[2]);
    foreach (var f in bnd.Files.Where(f => f.Name.EndsWith(".esd")))
    {
        string name = Path.GetFileNameWithoutExtension(f.Name);
        File.WriteAllText(Path.Combine(args[2], name + ".txt"), Dump(ReadEsd(f.Bytes.ToArray(), ctx)));
        Console.WriteLine($"dumped {name}");
    }
    return 0;
}

// Serializes a raw state's bytecode for equality checks.
static string StateKey(ESD.State s)
{
    static string Cmds(List<ESD.CommandCall> cs) =>
        string.Join(";", cs.Select(c => $"{c.CommandBank}:{c.CommandID}(" + string.Join(",", c.Arguments.Select(Convert.ToHexString)) + ")"));
    static string Conds(List<ESD.Condition> cs) =>
        string.Join("|", cs.Select(c => $"[{c.TargetState}:{Convert.ToHexString(c.Evaluator)}:{Cmds(c.PassCommands)}:{Conds(c.Subconditions)}]"));
    return $"{Cmds(s.EntryCommands)}#{Cmds(s.ExitCommands)}#{Cmds(s.WhileCommands)}#{Conds(s.Conditions)}";
}

static byte[] WriteEsd(ESDL esd, EzSembleContext ctx)
{
    var bw = new BinaryWriterEx(false);
    esd.WriteWithContext(bw, ctx);
    return bw.FinishBytes();
}

if (args.Length >= 3 && args[0] == "roundtrip")
{
    // roundtrip <file.talkesdbnd.dcx> <esdname>: read + write without changes, compare bytes
    var ctx = LoadContext();
    var bnd = BND4.Read(args[1]);
    var f = bnd.Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == args[2]);
    byte[] orig = f.Bytes.ToArray();
    byte[] again = WriteEsd(ReadEsd(orig, ctx), ctx);
    bool same = orig.AsSpan().SequenceEqual(again);
    Console.WriteLine($"{args[2]}: {orig.Length} -> {again.Length} bytes, identical={same}");
    byte[] raw = ESD.Read(orig).Write();
    Console.WriteLine($"raw SoulsFormats.ESD: {orig.Length} -> {raw.Length} bytes, identical={orig.AsSpan().SequenceEqual(raw)}");
    if (!same)
    {
        string a = Dump(ReadEsd(orig, ctx)), b = Dump(ReadEsd(again, ctx));
        Console.WriteLine($"text dump identical={a == b}");
    }
    return 0;
}

if (args.Length >= 5 && args[0] == "patch-grace")
{
    var bosses = Bosses.Load(args[3]);
    // patch-grace <in m00_00_00_00.talkesdbnd.dcx> <out m00_00_00_00.talkesdbnd.dcx> <bosses.json> <game msg dir> [language]
    // The boss list is in alphabetical order of its texts in language (a game msg folder, default rusru).
    string sortLanguage = args.Length >= 6 ? args[5] : "rusru";
    // Adds the "Reflections of Battle" entry to the site of grace menu (t000001000).
    // Vanilla states are edited as raw SoulsFormats.ESD so their bytecode is kept as is;
    // ESDLang is only used to assemble the new expressions and commands.
    var ctx = LoadContext();
    byte[] Expr(string s) => EzSembler.AssembleExpression(ctx, s);
    ESD.CommandCall Cmd(string s) => EzSembler.AssembleCommandCall(ctx, s);
    ESD.Condition Cond(long? target, string eval, params ESD.CommandCall[] pass) => new ESD.Condition
    {
        TargetState = target,
        Evaluator = Expr(eval),
        PassCommands = pass.ToList(),
    };
    ESD.Condition Branch(string eval, params ESD.Condition[] subs)
    {
        var c = Cond(null, eval);
        c.Subconditions = subs.ToList();
        return c;
    }

    var bnd = BND4.Read(args[1]);
    var file = bnd.Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == "t000001000");
    var esd = ESD.Read(file.Bytes.ToArray());

    const long mainGroup = 2147483616;   // site of grace main menu
    const long menuGroup = 2147483500;   // our boss list submenu (unused id in vanilla)
    const int mainEntry = 70;            // talk list index of our entry in the main menu
    const long mainCallState = 49;       // new state in the main menu that calls the submenu
    var main = esd.StateGroups[mainGroup];
    if (esd.StateGroups.ContainsKey(menuGroup) || main.ContainsKey(mainCallState))
        throw new Exception("t000001000 already patched");

    // State 15 adds the final "Leave" entry; our entry goes right before it.
    main[15].EntryCommands.Insert(0, Cmd($"AddTalkListData({mainEntry}, {Bosses.MenuMsgId}, -1)"));

    // State 8 dispatches on the chosen entry; the last condition is the fallback "if 1 -> 4".
    var dispatch = main[8].Conditions;
    dispatch.Insert(dispatch.Count - 1, Cond(mainCallState, $"GetREG0() == {mainEntry}"));

    // Call the submenu; it returns 1 when a reflection was started (then leave the grace menu, like "Leave" does).
    main[mainCallState] = new ESD.State
    {
        EntryCommands = { Cmd($"6:{menuGroup}()") },
        Conditions =
        {
            Branch("#B9 == 1", Cond(4, "1")),
            Branch("#B9 != #BA", Cond(1, "1")),
        },
    };

    // Submenu: every boss (defeated in the world or not) + Cancel.
    var menu = new Dictionary<long, ESD.State>();
    menu[0] = new ESD.State { Conditions = { Cond(1, "1") } };
    menu[1] = new ESD.State { EntryCommands = { Cmd("ClearTalkListData()") }, Conditions = { Cond(2, "1") } };
    var list = new ESD.State { Conditions = { Cond(3, "1") } };
    var sortNames = Bosses.LoadNpcNames(Path.Combine(args[4], sortLanguage));
    var sortCulture = System.Globalization.CultureInfo.GetCultureInfo(Bosses.SortCulture[sortLanguage]).CompareInfo;
    var ordered = bosses.OrderBy(b => Bosses.Text(b, sortLanguage, sortNames),
        Comparer<string>.Create((x, y) => sortCulture.Compare(x, y, System.Globalization.CompareOptions.IgnoreCase))).ToList();
    Console.WriteLine($"menu order {sortLanguage}: " + string.Join(" | ", ordered.Select(b => Bosses.Text(b, sortLanguage, sortNames))));
    // Option entries first, their text showing the current choice: NG+ cycle, and (DLC owned) Scadutree Blessing.
    list.EntryCommands.Add(Cmd($"AddTalkListDataIf(GetEventFlag({Bosses.NgCustomFlag}) == 0, {Bosses.NgEntry}, {Bosses.NgLabelMsgId}, -1)"));
    for (int n = 0; n <= Bosses.NgMax; n++)
        list.EntryCommands.Add(Cmd($"AddTalkListDataIf(GetEventFlag({Bosses.NgCustomFlag}) == 1 && GetEventFlag({Bosses.NgFlagBase + n}) == 1, " +
            $"{Bosses.NgEntry}, {Bosses.NgLabelMsgId + 1 + n}, -1)"));
    list.EntryCommands.Add(Cmd($"AddTalkListDataIf(GetEventFlag({Bosses.DlcOwnedFlag}) == 1 && GetEventFlag({Bosses.BlessingCustomFlag}) == 0, " +
        $"{Bosses.BlessingEntry}, {Bosses.BlessingLabelMsgId}, -1)"));
    for (int l = 0; l <= Bosses.BlessingMax; l++)
        list.EntryCommands.Add(Cmd($"AddTalkListDataIf(GetEventFlag({Bosses.DlcOwnedFlag}) == 1 && GetEventFlag({Bosses.BlessingCustomFlag}) == 1 && " +
            $"GetEventFlag({Bosses.BlessingFlagBase + l}) == 1, {Bosses.BlessingEntry}, {Bosses.BlessingLabelMsgId + 1 + l}, -1)"));
    list.EntryCommands.Add(Cmd($"AddTalkListData({Bosses.SeparatorEntry}, {Bosses.SeparatorMsgId}, -1)"));
    foreach (var b in ordered)
        list.EntryCommands.Add(Cmd(b.Dlc
            ? $"AddTalkListDataIf(GetEventFlag({Bosses.DlcOwnedFlag}) == 1, {b.ListIndex}, {b.MsgId}, -1)"
            : $"AddTalkListData({b.ListIndex}, {b.MsgId}, -1)"));
    list.EntryCommands.Add(Cmd("AddTalkListData(99, 20010079, -1)"));
    menu[2] = list;
    // "Menu closed" check: reuse the exact vanilla bytecode from the flask submenu (state 2147483600:3),
    // which carries continue-markers (0xA6) the plaintext assembler doesn't emit.
    var flaskMenuClosed = esd.StateGroups[2147483600][3].Conditions[0].Evaluator;
    menu[3] = new ESD.State
    {
        EntryCommands = { Cmd("ShowShopMessage(1)") },
        Conditions = { new ESD.Condition(4, flaskMenuClosed.ToArray()) },
    };
    var pick = new ESD.State();
    long stateId = 10;
    foreach (var b in bosses)
    {
        pick.Conditions.Add(Cond(stateId, $"GetTalkListEntryResult() == {b.ListIndex}"));
        menu[stateId] = new ESD.State
        {
            EntryCommands = { Cmd($"SetEventFlag({b.RequestFlag}, 1)") },
            Conditions = { Cond(null, "1", Cmd("7:-1(1)")) },
        };
        stateId++;
    }
    // Option entries: a value submenu (states 100.. / 200..), then back to the boss list (state 1).
    pick.Conditions.Add(Cond(100, $"GetTalkListEntryResult() == {Bosses.NgEntry}"));
    pick.Conditions.Add(Cond(200, $"GetTalkListEntryResult() == {Bosses.BlessingEntry}"));
    pick.Conditions.Add(Cond(1, $"GetTalkListEntryResult() == {Bosses.SeparatorEntry}"));
    pick.Conditions.Add(Cond(5, "1"));
    menu[4] = pick;
    menu[5] = new ESD.State { Conditions = { Cond(null, "1", Cmd("7:-1(0)")) } };
    // Value submenu at state s: list (s) -> wait closed (s + 1) -> dispatch (s + 2) -> set flags: "as in the
    // world" (s + 3: custom flag off), value v (s + 10 + v: custom flag on, only value flag v on).
    void ValueMenu(long s, int customFlag, int flagBase, int max, int choiceMsgId)
    {
        var listState = new ESD.State { EntryCommands = { Cmd("ClearTalkListData()"), Cmd($"AddTalkListData(1, {choiceMsgId}, -1)") }, Conditions = { Cond(s + 1, "1") } };
        for (int v = 0; v <= max; v++)
            listState.EntryCommands.Add(Cmd($"AddTalkListData({10 + v}, {choiceMsgId + 1 + v}, -1)"));
        listState.EntryCommands.Add(Cmd("AddTalkListData(99, 20010079, -1)"));
        menu[s] = listState;
        menu[s + 1] = new ESD.State { EntryCommands = { Cmd("ShowShopMessage(1)") }, Conditions = { new ESD.Condition(s + 2, flaskMenuClosed.ToArray()) } };
        var dispatchValue = new ESD.State();
        dispatchValue.Conditions.Add(Cond(s + 3, "GetTalkListEntryResult() == 1"));
        for (int v = 0; v <= max; v++)
            dispatchValue.Conditions.Add(Cond(s + 10 + v, $"GetTalkListEntryResult() == {10 + v}"));
        dispatchValue.Conditions.Add(Cond(1, "1"));
        menu[s + 2] = dispatchValue;
        ESD.State SetFlags(int? value)
        {
            var st = new ESD.State { Conditions = { Cond(1, "1") } };
            st.EntryCommands.Add(Cmd($"SetEventFlag({customFlag}, {(value.HasValue ? 1 : 0)})"));
            for (int v = 0; v <= max; v++)
                st.EntryCommands.Add(Cmd($"SetEventFlag({flagBase + v}, {(value == v ? 1 : 0)})"));
            return st;
        }
        menu[s + 3] = SetFlags(null);
        for (int v = 0; v <= max; v++)
            menu[s + 10 + v] = SetFlags(v);
    }
    ValueMenu(100, Bosses.NgCustomFlag, Bosses.NgFlagBase, Bosses.NgMax, Bosses.NgChoiceMsgId);
    ValueMenu(200, Bosses.BlessingCustomFlag, Bosses.BlessingFlagBase, Bosses.BlessingMax, Bosses.BlessingChoiceMsgId);
    esd.StateGroups[menuGroup] = menu;

    file.Bytes = esd.Write();
    bnd.Write(args[2]);

    // Every vanilla state other than the ones edited above must keep identical bytecode.
    var vanilla = ESD.Read(BND4.Read(args[1]).Files.First(f => f.Name == file.Name).Bytes.ToArray());
    var written = ESD.Read(BND4.Read(args[2]).Files.First(f => f.Name == file.Name).Bytes.ToArray());
    var edited = new HashSet<(long, long)> { (mainGroup, 8), (mainGroup, 15) };
    int compared = 0;
    foreach (var (g, states) in vanilla.StateGroups)
        foreach (var (s, st) in states)
        {
            if (edited.Contains((g, s))) continue;
            if (StateKey(st) != StateKey(written.StateGroups[g][s]))
                throw new Exception($"vanilla state {g}:{s} changed");
            compared++;
        }
    Console.WriteLine($"verified {compared} vanilla states unchanged");

    // Print the patched parts back through the disassembler for review.
    var check = ReadEsd(BND4.Read(args[2]).Files.First(f => f.Name == file.Name).Bytes.ToArray(), ctx);
    var view = new ESDL { StateGroups = new() { [mainGroup] = check.StateGroups[mainGroup], [menuGroup] = check.StateGroups[menuGroup] } };
    Console.Write(Dump(view));
    return 0;
}

if (args.Length >= 4 && args[0] == "emevd-merge")
{
    // emevd-merge <map.emevd.dcx> <template.emevd.dcx> <out.emevd.dcx>
    // Adds the template's events (except 0) to the map's events and appends the template's event 0
    // instructions (its InitializeEvent calls) to the map's event 0. Vanilla events are copied as is.
    var map = EMEVD.Read(args[1]);
    var template = EMEVD.Read(args[2]);
    // The map's init event: 0, or 200 in some overworld tiles (e.g. m60_52_52_00) that have no event 0.
    // A map with neither (e.g. m60_51_38_00, no events at all) gets the template's event 0 as its own.
    long initId = map.Events.Any(e => e.ID == 0) ? 0 : 200;
    var map0 = map.Events.FirstOrDefault(e => e.ID == initId);
    if (map0 == null)
    {
        initId = 0;
        map0 = new EMEVD.Event(0, EMEVD.Event.RestBehaviorType.Default);
        map.Events.Insert(0, map0);
    }
    foreach (var ev in template.Events)
    {
        if (ev.ID == 0)
        {
            map0.Instructions.AddRange(ev.Instructions);
            continue;
        }
        if (map.Events.Any(e => e.ID == ev.ID))
            throw new Exception($"event {ev.ID} already exists in {Path.GetFileName(args[1])}");
        map.Events.Add(ev);
    }
    map.Write(args[3]);

    // Check: every vanilla event is unchanged; event 0 only got the template lines appended.
    static string Key(EMEVD.Event e) => string.Join(";", e.Instructions.Select(i => $"{i.Bank}:{i.ID}:{Convert.ToHexString(i.ArgData)}"))
        + "#" + string.Join(";", e.Parameters.Select(p => $"{p.InstructionIndex}:{p.TargetStartByte}:{p.SourceStartByte}:{p.ByteCount}"));
    var vanilla = EMEVD.Read(args[1]);
    var written = EMEVD.Read(args[3]);
    foreach (var ev in vanilla.Events)
    {
        var w = written.Events.First(e => e.ID == ev.ID);
        if (ev.ID == initId)
        {
            if (Key(new EMEVD.Event { Instructions = w.Instructions.Take(ev.Instructions.Count).ToList(), Parameters = w.Parameters }) != Key(ev))
                throw new Exception($"event {initId} changed");
        }
        else if (Key(w) != Key(ev) || w.RestBehavior != ev.RestBehavior)
            throw new Exception($"vanilla event {ev.ID} changed");
    }
    Console.WriteLine($"{Path.GetFileName(args[1])}: {vanilla.Events.Count} -> {written.Events.Count} events, " +
        $"event {initId} +{written.Events.First(e => e.ID == initId).Instructions.Count - (vanilla.Events.FirstOrDefault(e => e.ID == initId)?.Instructions.Count ?? 0)} lines, vanilla events unchanged");
    return 0;
}

if (args.Length >= 3 && args[0] == "anims")
{
    // anims <regex> <file.anibnd.dcx...>: animation files (hkx) whose name matches regex, per bnd
    var re = new System.Text.RegularExpressions.Regex(args[1]);
    foreach (var path in args.Skip(2))
    {
        var names = BND4.Read(path).Files.Select(f => Path.GetFileNameWithoutExtension(f.Name)).Where(n => re.IsMatch(n));
        Console.WriteLine($"{Path.GetFileName(path)}: {string.Join(" ", names)}");
    }
    return 0;
}

if (args.Length >= 2 && args[0] == "list")
{
    // list <bnd...>: file names inside each bnd
    foreach (var path in args.Skip(1))
        Console.WriteLine($"{Path.GetFileName(path)}: " + string.Join(", ", BND4.Read(path).Files.Select(f => Path.GetFileName(f.Name))));
    return 0;
}

if (args.Length >= 5 && args[0] == "hex")
{
    // hex <file.talkesdbnd.dcx> <esdname> <group> <state>: raw bytecode of one state
    var f = BND4.Read(args[1]).Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == args[2]);
    var st = ESD.Read(f.Bytes.ToArray()).StateGroups[long.Parse(args[3])][long.Parse(args[4])];
    Console.WriteLine(StateKey(st).Replace("#", "\n#").Replace("|", "\n|"));
    return 0;
}

if (args.Length >= 4 && args[0] == "patch-msg")
{
    var bosses = Bosses.Load(args[3]);
    // patch-msg <game msg dir> <out msg dir> <bosses.json>: adds menu texts to EventTextForTalk for every language.
    // menu_dlc01/menu_dlc02 each carry a full copy of EventTextForTalk and the newest one wins in game,
    // so the entries go into all of them.
    foreach (string langDir in Directory.GetDirectories(args[1]))
    {
        string lang = Path.GetFileName(langDir);
        var names = Bosses.LoadNpcNames(langDir);
        string title = Bosses.MenuTitle(lang);

        var written = new List<string>();
        foreach (string menu in new[] { "menu.msgbnd.dcx", "menu_dlc01.msgbnd.dcx", "menu_dlc02.msgbnd.dcx" })
        {
            string menuPath = Path.Combine(langDir, menu);
            if (!File.Exists(menuPath)) continue;
            var bnd = BND4.Read(menuPath);
            var talkFile = bnd.Files.FirstOrDefault(f => Path.GetFileNameWithoutExtension(f.Name) == "EventTextForTalk");
            if (talkFile == null) continue;
            var fmg = FMG.Read(talkFile.Bytes.ToArray());
            void Set(int id, string text)
            {
                fmg.Entries.RemoveAll(e => e.ID == id);
                fmg.Entries.Add(new FMG.Entry(id, text));
            }
            Set(Bosses.MenuMsgId, title);
            foreach (var b in bosses)
                Set(b.MsgId, Bosses.Text(b, lang, names));
            foreach (var (id, text) in Bosses.OptionTexts(lang))
                Set(id, text);
            fmg.Entries.Sort((x, y) => x.ID.CompareTo(y.ID));
            talkFile.Bytes = fmg.Write();

            // Prompt of our "begin the battle" action button (ActionButtonParam 7980000).
            var buttonFile = bnd.Files.FirstOrDefault(f => Path.GetFileNameWithoutExtension(f.Name) == "ActionButtonText");
            if (buttonFile != null)
            {
                var buttons = FMG.Read(buttonFile.Bytes.ToArray());
                buttons.Entries.RemoveAll(e => e.ID == Bosses.BeginPromptMsgId);
                buttons.Entries.Add(new FMG.Entry(Bosses.BeginPromptMsgId,
                    Bosses.BeginPrompt(lang)));
                buttons.Entries.Sort((x, y) => x.ID.CompareTo(y.ID));
                buttonFile.Bytes = buttons.Write();
            }

            string outDir = Path.Combine(args[2], lang);
            Directory.CreateDirectory(outDir);
            bnd.Write(Path.Combine(outDir, menu));
            written.Add(menu.Replace(".msgbnd.dcx", ""));
        }
        if (written.Count > 0)
            Console.WriteLine($"{lang} [{string.Join(", ", written)}]: {title} / " +
                string.Join(", ", bosses.Select(b => Bosses.Text(b, lang, names))));
    }
    return 0;
}

if (args.Length >= 2 && args[0] == "fmginfo")
{
    // fmginfo <file.msgbnd.dcx> [id...]: bnd/fmg header details and raw text of entries
    var bnd = BND4.Read(args[1]);
    Console.WriteLine($"bnd: compression={bnd.Compression} version={bnd.Version} format={bnd.Format} unicode={bnd.Unicode} ext={bnd.Extended} files={bnd.Files.Count}");
    var f = bnd.Files.First(f => Path.GetFileNameWithoutExtension(f.Name) == "EventTextForTalk");
    var fmg = FMG.Read(f.Bytes.ToArray());
    Console.WriteLine($"file: id={f.ID} name={f.Name} flags={f.Flags} bytes={f.Bytes.Length}");
    Console.WriteLine($"fmg: version={fmg.Version} bigendian={fmg.BigEndian} entries={fmg.Entries.Count}");
    Console.WriteLine("first bytes: " + Convert.ToHexString(f.Bytes.Take(48).ToArray()));
    foreach (var id in args.Skip(2).Select(int.Parse))
    {
        var e = fmg.Entries.FirstOrDefault(e => e.ID == id);
        Console.WriteLine($"{id}: " + (e == null ? "<missing>" : string.Join(" ", e.Text.Select(c => ((int)c).ToString("X4")))));
    }
    return 0;
}

if (args.Length >= 3 && args[0] == "fmg")
{
    // fmg <file.msgbnd.dcx> <outdir>: writes every FMG in the bnd as "id<TAB>text" lines
    var bnd = BND4.Read(args[1]);
    Directory.CreateDirectory(args[2]);
    foreach (var f in bnd.Files.Where(f => f.Name.EndsWith(".fmg")))
    {
        var fmg = FMG.Read(f.Bytes.ToArray());
        var lines = fmg.Entries.Where(e => !string.IsNullOrEmpty(e.Text))
            .Select(e => $"{e.ID}\t{e.Text.Replace("\r", "").Replace("\n", "\\n")}");
        File.WriteAllLines(Path.Combine(args[2], Path.GetFileNameWithoutExtension(f.Name) + ".txt"), lines);
    }
    Console.WriteLine($"dumped {bnd.Files.Count} files");
    return 0;
}

Console.WriteLine("Usage: EsdUtil dump <file.talkesdbnd.dcx> <outdir>");
Console.WriteLine("       EsdUtil fmg <file.msgbnd.dcx> <outdir>");
return 1;
