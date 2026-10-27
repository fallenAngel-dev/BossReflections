using System.Text.Json;
using SoulsFormats;

// Bosses available for reflections, read from src\bosses.json.
//   ListIndex  - talk list index in the submenu (1..98): position in the file + 1
//   MsgId      - new EventTextForTalk entry shown in the submenu: 29800010 + position
//   NameId     - vanilla NpcName entry (boss health bar name) used as the menu text...
//   MenuText   - ...unless bosses.json gives one per language (other languages: MenuNameIds, else engus)
//   MenuNameIds- names joined with " & " for languages MenuText doesn't have
//   RequestFlag- set by the grace menu, consumed by the common event that starts the fight
//   Dlc        - Shadow of the Erdtree boss: listed only when the game has the DLC (system flag 6951)
public record Boss(string Key, int ListIndex, long DefeatFlag, long RequestFlag, int MsgId, int NameId,
    Dictionary<string, string> MenuText, bool Dlc, int[] MenuNameIds);

public static class Bosses
{
    // EventTextForTalk entry for the main menu item.
    public const int MenuMsgId = 29800000;

    // ActionButtonText entry of the "begin the battle" prompt (ActionButtonParam 7980000, event 7980013).
    public const int BeginPromptMsgId = 29800001;
    // System flag the game sets when Shadow of the Erdtree is owned (vanilla checks it at the DLC entrance).
    public const int DlcOwnedFlag = 6951;

    // NG+ / Scadutree Blessing choice of the reflections (events 7980020 / 7980021 read these flags):
    // the "custom" flag on = one of the value flags says the choice, off = as in the world.
    public const int NgCustomFlag = 10000900;   // value flags 10000901 + T, T = 0 (NG) .. 7 (NG+7)
    public const int NgFlagBase = 10000901;
    public const int NgMax = 7;
    public const int BlessingCustomFlag = 10000910;   // value flags 10000911 + L, L = 0 .. 20
    public const int BlessingFlagBase = 10000911;
    public const int BlessingMax = 20;

    // Talk list indices of the two option entries at the top of the boss list (bosses use 1..95, Cancel 99).
    public const int NgEntry = 96;
    public const int BlessingEntry = 97;

    // EventTextForTalk entries: the option entries showing the current choice (default + one per value),
    // and the choices in their submenus (default + one per value).
    public const int NgLabelMsgId = 29800100;        // + 1 + T
    public const int NgChoiceMsgId = 29800110;       // + 1 + T
    public const int BlessingLabelMsgId = 29800200;  // + 1 + L
    public const int BlessingChoiceMsgId = 29800230; // + 1 + L

    // Talk list index and text of the separator line between the options and the bosses (picking it just
    // shows the list again).
    public const int SeparatorEntry = 98;
    public const int SeparatorMsgId = 29800002;
    const string Separator = "————————————————";

    // The mod's texts per game language. Journey: the game's own word for an NG cycle ("Begin Journey 2"),
    // value(n) its wording of cycle n (1 = NG); Blessing: the game's own name of the Scadutree Blessing
    // (GR_MenuText_dlc01 10410). araae falls back to engus: the game stores Arabic pre-shaped, which plain
    // text here isn't.
    record Lang(string Title, string Begin, string Journey, Func<int, string> JourneyValue, string AsWorld,
        string Blessing, string AsCharacter, string Level);

    static readonly Dictionary<string, Lang> Langs = new()
    {
        ["engus"] = new("Reflections of Battle", "Begin the battle", "Journey", n => $"{n}", "as in the world",
            "Scadutree Blessing", "as the character's", "Level"),
        ["rusru"] = new("Отражения битв", "Начать бой", "Цикл НГ", n => n == 1 ? "НГ" : $"НГ+{n - 1}", "как в мире",
            "Уровень Древа упадка", "как у персонажа", "Уровень"),
        ["deude"] = new("Kampferinnerungen", "Kampf beginnen", "Reise", n => $"{n}", "wie in der Welt",
            "Segen des Scadubaums", "wie beim Charakter", "Stufe"),
        ["frafr"] = new("Reflets de combat", "Commencer le combat", "Aventure", n => $"{n}", "comme dans le monde",
            "Béné. de l'Arbre-Occulte", "comme le personnage", "Niveau"),
        ["itait"] = new("Riflessi di battaglia", "Inizia la battaglia", "Viaggio", n => $"n. {n}", "come nel mondo",
            "Benedizione dell'Albero Ombra", "come il personaggio", "Livello"),
        ["spaes"] = new("Reflejos de batalla", "Comenzar la batalla", "Odisea", n => $"núm. {n}", "como en el mundo",
            "Bendición del Árbol Umbrío", "como el personaje", "Nivel"),
        ["spaar"] = new("Reflejos de batalla", "Comenzar la batalla", "Viaje", n => $"{n}", "como en el mundo",
            "Bendición del Noctárbol", "como el personaje", "Nivel"),
        ["porbr"] = new("Reflexos de batalha", "Iniciar a batalha", "Jornada", n => $"{n}", "como no mundo",
            "Bênção da Umbrárvore", "como o personagem", "Nível"),
        ["polpl"] = new("Odbicia bitew", "Rozpocznij walkę", "Podróż", n => $"{n}", "jak w świecie",
            "Błogosławieństwo Ostrodrzewa", "jak u postaci", "Poziom"),
        ["jpnjp"] = new("戦いの追憶", "戦いを始める", "周回", n => $"{n}周目", "ワールドと同じ",
            "影樹の加護", "キャラクターと同じ", "レベル"),
        ["korkr"] = new("전투의 회상", "전투 시작", "회차", n => $"{n}주차", "월드와 동일",
            "그림자 나무의 가호", "캐릭터와 동일", "레벨"),
        ["zhocn"] = new("战斗回忆", "开始战斗", "周目", n => $"第{n}次的世界", "与世界相同",
            "幽影树庇佑", "与角色相同", "等级"),
        ["zhotw"] = new("戰鬥回憶", "開始戰鬥", "周目", n => $"第{n}次的世界", "與世界相同",
            "幽影樹庇佑", "與角色相同", "等級"),
        ["thath"] = new("ภาพ​สะท้อน​แห่ง​การ​ต่อสู้", "เริ่ม​การ​ต่อสู้", "รอบ", n => $"รอบ​ที่ {n}", "ตาม​โลก​ปัจจุบัน",
            "ความ​คุ้มครอง​แห่ง​พฤกษา​เงา", "ตาม​ตัว​ละคร", "ระดับ"),
    };

    static readonly HashSet<string> SelfNamedCycle = new() { "jpnjp", "korkr", "zhocn", "zhotw", "thath" };

    static Lang L(string lang) => Langs.GetValueOrDefault(lang, Langs["engus"]);

    public static string MenuTitle(string lang) => L(lang).Title;
    public static string BeginPrompt(string lang) => L(lang).Begin;

    // The option texts of one language: the option entries (current choice) and the submenu choices.
    // NG cycle T is the game's cycle T + 1 ("Journey 4"), with "(NG+T)" for clarity (Russian says NG itself).
    public static Dictionary<int, string> OptionTexts(string lang)
    {
        var x = L(lang);
        bool ru = lang == "rusru";
        string Cycle(int t) => ru ? x.JourneyValue(t + 1) : $"{x.JourneyValue(t + 1)} ({(t == 0 ? "NG" : $"NG+{t}")})";
        var texts = new Dictionary<int, string>
        {
            [SeparatorMsgId] = Separator,
            [NgLabelMsgId] = $"{x.Journey}: {x.AsWorld}",
            [NgChoiceMsgId] = Capitalize(x.AsWorld),
            [BlessingLabelMsgId] = $"{x.Blessing}: {x.AsCharacter}",
            [BlessingChoiceMsgId] = Capitalize(x.AsCharacter),
        };
        for (int n = 0; n <= NgMax; n++)
        {
            texts[NgLabelMsgId + 1 + n] = $"{x.Journey}: {Cycle(n)}";
            // Languages whose cycle wording already names it ("4周目") show it alone.
            texts[NgChoiceMsgId + 1 + n] = ru || SelfNamedCycle.Contains(lang) ? Cycle(n) : $"{x.Journey} {Cycle(n)}";
        }
        for (int l = 0; l <= BlessingMax; l++)
        {
            texts[BlessingLabelMsgId + 1 + l] = $"{x.Blessing}: {l}";
            texts[BlessingChoiceMsgId + 1 + l] = $"{x.Level} {l}";
        }
        return texts;
    }

    static string Capitalize(string s) => s.Length > 0 ? char.ToUpper(s[0]) + s[1..] : s;
    // Culture for the alphabetical order of the boss list, per game msg language folder. The menu (talk
    // script) can't tell the game language, so build.ps1 makes one per language and the launcher picks it.
    public static readonly Dictionary<string, string> SortCulture = new()
    {
        ["araae"] = "ar-AE", ["deude"] = "de-DE", ["engus"] = "en-US", ["frafr"] = "fr-FR", ["itait"] = "it-IT",
        ["jpnjp"] = "ja-JP", ["korkr"] = "ko-KR", ["polpl"] = "pl-PL", ["porbr"] = "pt-BR", ["rusru"] = "ru-RU",
        ["spaar"] = "es-MX", ["spaes"] = "es-ES", ["thath"] = "th-TH", ["zhocn"] = "zh-CN", ["zhotw"] = "zh-TW",
    };

    public static Boss[] Load(string jsonPath)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(jsonPath));
        var list = doc.RootElement.GetProperty("bosses").EnumerateArray().Select((b, i) => new Boss(
            b.GetProperty("key").GetString(),
            i + 1,
            b.GetProperty("defeatFlag").GetInt64(),
            b.GetProperty("flags").GetProperty("request").GetInt64(),
            29800010 + i,
            b.GetProperty("nameId").GetInt32(),
            b.TryGetProperty("menuText", out var mt)
                ? mt.EnumerateObject().ToDictionary(p => p.Name, p => p.Value.GetString())
                : null,
            b.TryGetProperty("dlc", out var dlc) && dlc.GetBoolean(),
            b.TryGetProperty("menuNameIds", out var mn) ? mn.EnumerateArray().Select(e => e.GetInt32()).ToArray() : null)).ToArray();
        if (list.Length > 95)
            throw new Exception("at most 95 bosses fit in the submenu (96/97: options, 99: Cancel)");
        return list;
    }

    // NpcName texts of one language folder of the game's msg directory (base game + DLC files).
    public static Dictionary<int, string> LoadNpcNames(string langDir)
    {
        var names = new Dictionary<int, string>();
        foreach (string item in new[] { "item.msgbnd.dcx", "item_dlc01.msgbnd.dcx", "item_dlc02.msgbnd.dcx" })
        {
            string p = Path.Combine(langDir, item);
            if (!File.Exists(p)) continue;
            foreach (var f in BND4.Read(p).Files.Where(f => Path.GetFileNameWithoutExtension(f.Name).StartsWith("NpcName")))
                foreach (var e in FMG.Read(f.Bytes.ToArray()).Entries.Where(e => !string.IsNullOrEmpty(e.Text)))
                    names[e.ID] = e.Text;
        }
        return names;
    }

    // Text of a boss's submenu entry in one language.
    // MenuText for the language if given, else the names of MenuNameIds joined with " & " (Radagon and the
    // Elden Beast in every language), else MenuText engus, else the health bar name.
    public static string Text(Boss b, string lang, Dictionary<int, string> names)
    {
        if (b.MenuText != null && b.MenuText.TryGetValue(lang, out string t)) return t;
        if (b.MenuNameIds != null && b.MenuNameIds.All(names.ContainsKey)) return string.Join(" & ", b.MenuNameIds.Select(id => names[id]));
        if (b.MenuText != null && b.MenuText.TryGetValue("engus", out t)) return t;
        return names.TryGetValue(b.NameId, out string n) ? n : $"Boss {b.NameId}";
    }
}
