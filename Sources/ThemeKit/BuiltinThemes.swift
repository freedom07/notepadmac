import Foundation

public enum BuiltinThemes {

    /// All built-in themes shipped with NotepadNext.
    public static let allBuiltinThemes: [Theme] = [
        monokai, oneDark, dracula, nord,
        solarizedLight, githubLight, defaultLight, defaultDark,
        solarizedDark, tokyoNight, catppuccinMocha, gruvboxDark,
        oneLightTheme, tomorrowTheme, zenburn, obsidian,
        bespin, blackBoard, twilight, vibrantInk,
        rubyBlue, vimDarkBlue, deepBlack, choco,
    ]

    // MARK: - Monokai

    public static let monokai = Theme(
        name: "Monokai",
        type: .dark,
        colors: [
            "editorBackground": "#272822",
            "editorForeground": "#F8F8F2",
            "lineHighlight": "#3E3D32",
            "selectionBackground": "#49483E",
            "cursor": "#F8F8F0",
            "gutterBackground": "#272822",
            "gutterForeground": "#90908A",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#F92672"),
            "string": TokenStyle(foreground: "#E6DB74"),
            "comment": TokenStyle(foreground: "#75715E"),
            "number": TokenStyle(foreground: "#AE81FF"),
            "type": TokenStyle(foreground: "#66D9EF", fontStyle: "italic"),
            "function": TokenStyle(foreground: "#A6E22E"),
            "variable": TokenStyle(foreground: "#F8F8F2"),
            "operator": TokenStyle(foreground: "#F92672"),
            "punctuation": TokenStyle(foreground: "#F8F8F2"),
            "preprocessor": TokenStyle(foreground: "#F92672"),
            "tag": TokenStyle(foreground: "#F92672"),
        ]
    )

    // MARK: - One Dark

    public static let oneDark = Theme(
        name: "One Dark",
        type: .dark,
        colors: [
            "editorBackground": "#282C34",
            "editorForeground": "#ABB2BF",
            "lineHighlight": "#2C313C",
            "selectionBackground": "#3E4451",
            "cursor": "#528BFF",
            "gutterBackground": "#282C34",
            "gutterForeground": "#4B5263",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#C678DD"),
            "string": TokenStyle(foreground: "#98C379"),
            "comment": TokenStyle(foreground: "#5C6370", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#D19A66"),
            "type": TokenStyle(foreground: "#E5C07B"),
            "function": TokenStyle(foreground: "#61AFEF"),
            "variable": TokenStyle(foreground: "#E06C75"),
            "operator": TokenStyle(foreground: "#56B6C2"),
            "punctuation": TokenStyle(foreground: "#ABB2BF"),
            "preprocessor": TokenStyle(foreground: "#C678DD"),
            "tag": TokenStyle(foreground: "#E06C75"),
        ]
    )

    // MARK: - Dracula

    public static let dracula = Theme(
        name: "Dracula",
        type: .dark,
        colors: [
            "editorBackground": "#282A36",
            "editorForeground": "#F8F8F2",
            "lineHighlight": "#44475A",
            "selectionBackground": "#44475A",
            "cursor": "#F8F8F2",
            "gutterBackground": "#282A36",
            "gutterForeground": "#6272A4",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#FF79C6"),
            "string": TokenStyle(foreground: "#F1FA8C"),
            "comment": TokenStyle(foreground: "#6272A4"),
            "number": TokenStyle(foreground: "#BD93F9"),
            "type": TokenStyle(foreground: "#8BE9FD", fontStyle: "italic"),
            "function": TokenStyle(foreground: "#50FA7B"),
            "variable": TokenStyle(foreground: "#F8F8F2"),
            "operator": TokenStyle(foreground: "#FF79C6"),
            "punctuation": TokenStyle(foreground: "#F8F8F2"),
            "preprocessor": TokenStyle(foreground: "#FF79C6"),
            "tag": TokenStyle(foreground: "#FF79C6"),
        ]
    )

    // MARK: - Nord

    public static let nord = Theme(
        name: "Nord",
        type: .dark,
        colors: [
            "editorBackground": "#2E3440",
            "editorForeground": "#D8DEE9",
            "lineHighlight": "#3B4252",
            "selectionBackground": "#434C5E",
            "cursor": "#D8DEE9",
            "gutterBackground": "#2E3440",
            "gutterForeground": "#4C566A",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#81A1C1"),
            "string": TokenStyle(foreground: "#A3BE8C"),
            "comment": TokenStyle(foreground: "#616E88", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#B48EAD"),
            "type": TokenStyle(foreground: "#8FBCBB"),
            "function": TokenStyle(foreground: "#88C0D0"),
            "variable": TokenStyle(foreground: "#D8DEE9"),
            "operator": TokenStyle(foreground: "#81A1C1"),
            "punctuation": TokenStyle(foreground: "#ECEFF4"),
            "preprocessor": TokenStyle(foreground: "#5E81AC"),
            "tag": TokenStyle(foreground: "#81A1C1"),
        ]
    )

    // MARK: - Solarized Light

    public static let solarizedLight = Theme(
        name: "Solarized Light",
        type: .light,
        colors: [
            "editorBackground": "#FDF6E3",
            "editorForeground": "#657B83",
            "lineHighlight": "#EEE8D5",
            "selectionBackground": "#D6D0BD",
            "cursor": "#657B83",
            "gutterBackground": "#EEE8D5",
            "gutterForeground": "#93A1A1",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#859900"),
            "string": TokenStyle(foreground: "#2AA198"),
            "comment": TokenStyle(foreground: "#93A1A1", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#D33682"),
            "type": TokenStyle(foreground: "#268BD2"),
            "function": TokenStyle(foreground: "#B58900"),
            "variable": TokenStyle(foreground: "#657B83"),
            "operator": TokenStyle(foreground: "#859900"),
            "punctuation": TokenStyle(foreground: "#657B83"),
            "preprocessor": TokenStyle(foreground: "#CB4B16"),
            "tag": TokenStyle(foreground: "#268BD2"),
        ]
    )

    // MARK: - GitHub Light

    public static let githubLight = Theme(
        name: "GitHub Light",
        type: .light,
        colors: [
            "editorBackground": "#FFFFFF",
            "editorForeground": "#24292E",
            "lineHighlight": "#F6F8FA",
            "selectionBackground": "#C8E1FF",
            "cursor": "#24292E",
            "gutterBackground": "#FFFFFF",
            "gutterForeground": "#BABBBD",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#D73A49"),
            "string": TokenStyle(foreground: "#032F62"),
            "comment": TokenStyle(foreground: "#6A737D", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#005CC5"),
            "type": TokenStyle(foreground: "#6F42C1"),
            "function": TokenStyle(foreground: "#6F42C1"),
            "variable": TokenStyle(foreground: "#E36209"),
            "operator": TokenStyle(foreground: "#D73A49"),
            "punctuation": TokenStyle(foreground: "#24292E"),
            "preprocessor": TokenStyle(foreground: "#D73A49"),
            "tag": TokenStyle(foreground: "#22863A"),
        ]
    )

    // MARK: - Default Light

    public static let defaultLight = Theme(
        name: "Default Light",
        type: .light,
        colors: [
            "editorBackground": "#FFFFFF",
            "editorForeground": "#000000",
            "lineHighlight": "#F5F5F5",
            "selectionBackground": "#B4D5FE",
            "cursor": "#000000",
            "gutterBackground": "#F5F5F5",
            "gutterForeground": "#AAAAAA",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#AF00DB"),
            "string": TokenStyle(foreground: "#A31515"),
            "comment": TokenStyle(foreground: "#008000", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#098658"),
            "type": TokenStyle(foreground: "#267F99"),
            "function": TokenStyle(foreground: "#795E26"),
            "variable": TokenStyle(foreground: "#001080"),
            "operator": TokenStyle(foreground: "#000000"),
            "punctuation": TokenStyle(foreground: "#000000"),
            "preprocessor": TokenStyle(foreground: "#AF00DB"),
            "tag": TokenStyle(foreground: "#800000"),
        ]
    )

    // MARK: - Default Dark

    public static let defaultDark = Theme(
        name: "Default Dark",
        type: .dark,
        colors: [
            "editorBackground": "#1E1E1E",
            "editorForeground": "#D4D4D4",
            "lineHighlight": "#2A2D2E",
            "selectionBackground": "#264F78",
            "cursor": "#AEAFAD",
            "gutterBackground": "#1E1E1E",
            "gutterForeground": "#858585",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#569CD6"),
            "string": TokenStyle(foreground: "#CE9178"),
            "comment": TokenStyle(foreground: "#6A9955", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#B5CEA8"),
            "type": TokenStyle(foreground: "#4EC9B0"),
            "function": TokenStyle(foreground: "#DCDCAA"),
            "variable": TokenStyle(foreground: "#9CDCFE"),
            "operator": TokenStyle(foreground: "#D4D4D4"),
            "punctuation": TokenStyle(foreground: "#D4D4D4"),
            "preprocessor": TokenStyle(foreground: "#C586C0"),
            "tag": TokenStyle(foreground: "#569CD6"),
        ]
    )

    // MARK: - Solarized Dark

    public static let solarizedDark = Theme(
        name: "Solarized Dark",
        type: .dark,
        colors: [
            "editorBackground": "#002B36",
            "editorForeground": "#839496",
            "lineHighlight": "#073642",
            "selectionBackground": "#174652",
            "cursor": "#839496",
            "gutterBackground": "#002B36",
            "gutterForeground": "#586E75",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#859900"),
            "string": TokenStyle(foreground: "#2AA198"),
            "comment": TokenStyle(foreground: "#586E75", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#D33682"),
            "type": TokenStyle(foreground: "#268BD2"),
            "function": TokenStyle(foreground: "#B58900"),
            "variable": TokenStyle(foreground: "#839496"),
            "operator": TokenStyle(foreground: "#859900"),
            "punctuation": TokenStyle(foreground: "#839496"),
            "preprocessor": TokenStyle(foreground: "#CB4B16"),
            "tag": TokenStyle(foreground: "#268BD2"),
        ]
    )

    // MARK: - Tokyo Night

    public static let tokyoNight = Theme(
        name: "Tokyo Night",
        type: .dark,
        colors: [
            "editorBackground": "#1A1B26",
            "editorForeground": "#A9B1D6",
            "lineHighlight": "#232433",
            "selectionBackground": "#33467C",
            "cursor": "#C0CAF5",
            "gutterBackground": "#1A1B26",
            "gutterForeground": "#3B4261",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#BB9AF7"),
            "string": TokenStyle(foreground: "#9ECE6A"),
            "comment": TokenStyle(foreground: "#565F89", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FF9E64"),
            "type": TokenStyle(foreground: "#7AA2F7"),
            "function": TokenStyle(foreground: "#7DCFFF"),
            "variable": TokenStyle(foreground: "#C0CAF5"),
            "operator": TokenStyle(foreground: "#89DDFF"),
            "punctuation": TokenStyle(foreground: "#A9B1D6"),
            "preprocessor": TokenStyle(foreground: "#BB9AF7"),
            "tag": TokenStyle(foreground: "#F7768E"),
        ]
    )

    // MARK: - Catppuccin Mocha

    public static let catppuccinMocha = Theme(
        name: "Catppuccin Mocha",
        type: .dark,
        colors: [
            "editorBackground": "#1E1E2E",
            "editorForeground": "#CDD6F4",
            "lineHighlight": "#313244",
            "selectionBackground": "#45475A",
            "cursor": "#F5E0DC",
            "gutterBackground": "#1E1E2E",
            "gutterForeground": "#6C7086",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#CBA6F7"),
            "string": TokenStyle(foreground: "#A6E3A1"),
            "comment": TokenStyle(foreground: "#6C7086", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FAB387"),
            "type": TokenStyle(foreground: "#89B4FA"),
            "function": TokenStyle(foreground: "#F5C2E7"),
            "variable": TokenStyle(foreground: "#CDD6F4"),
            "operator": TokenStyle(foreground: "#89DCEB"),
            "punctuation": TokenStyle(foreground: "#BAC2DE"),
            "preprocessor": TokenStyle(foreground: "#F38BA8"),
            "tag": TokenStyle(foreground: "#F38BA8"),
        ]
    )

    // MARK: - Gruvbox Dark

    public static let gruvboxDark = Theme(
        name: "Gruvbox Dark",
        type: .dark,
        colors: [
            "editorBackground": "#282828",
            "editorForeground": "#EBDBB2",
            "lineHighlight": "#3C3836",
            "selectionBackground": "#504945",
            "cursor": "#EBDBB2",
            "gutterBackground": "#282828",
            "gutterForeground": "#928374",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#FB4934"),
            "string": TokenStyle(foreground: "#B8BB26"),
            "comment": TokenStyle(foreground: "#928374", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#D3869B"),
            "type": TokenStyle(foreground: "#83A598"),
            "function": TokenStyle(foreground: "#FABD2F"),
            "variable": TokenStyle(foreground: "#EBDBB2"),
            "operator": TokenStyle(foreground: "#FE8019"),
            "punctuation": TokenStyle(foreground: "#EBDBB2"),
            "preprocessor": TokenStyle(foreground: "#8EC07C"),
            "tag": TokenStyle(foreground: "#FB4934"),
        ]
    )

    // MARK: - One Light

    public static let oneLightTheme = Theme(
        name: "One Light",
        type: .light,
        colors: [
            "editorBackground": "#FAFAFA",
            "editorForeground": "#383A42",
            "lineHighlight": "#F0F0F0",
            "selectionBackground": "#BFCEFF",
            "cursor": "#526FFF",
            "gutterBackground": "#FAFAFA",
            "gutterForeground": "#9D9D9F",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#A626A4"),
            "string": TokenStyle(foreground: "#50A14F"),
            "comment": TokenStyle(foreground: "#A0A1A7", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#986801"),
            "type": TokenStyle(foreground: "#C18401"),
            "function": TokenStyle(foreground: "#4078F2"),
            "variable": TokenStyle(foreground: "#E45649"),
            "operator": TokenStyle(foreground: "#0184BC"),
            "punctuation": TokenStyle(foreground: "#383A42"),
            "preprocessor": TokenStyle(foreground: "#A626A4"),
            "tag": TokenStyle(foreground: "#E45649"),
        ]
    )

    // MARK: - Tomorrow

    public static let tomorrowTheme = Theme(
        name: "Tomorrow",
        type: .light,
        colors: [
            "editorBackground": "#FFFFFF",
            "editorForeground": "#4D4D4C",
            "lineHighlight": "#EFEFEF",
            "selectionBackground": "#D6D6D6",
            "cursor": "#4D4D4C",
            "gutterBackground": "#FFFFFF",
            "gutterForeground": "#8E908C",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#8959A8"),
            "string": TokenStyle(foreground: "#718C00"),
            "comment": TokenStyle(foreground: "#8E908C", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#F5871F"),
            "type": TokenStyle(foreground: "#EAB700"),
            "function": TokenStyle(foreground: "#4271AE"),
            "variable": TokenStyle(foreground: "#C82829"),
            "operator": TokenStyle(foreground: "#3E999F"),
            "punctuation": TokenStyle(foreground: "#4D4D4C"),
            "preprocessor": TokenStyle(foreground: "#8959A8"),
            "tag": TokenStyle(foreground: "#C82829"),
        ]
    )

    // MARK: - Zenburn

    public static let zenburn = Theme(
        name: "Zenburn",
        type: .dark,
        colors: [
            "editorBackground": "#3F3F3F",
            "editorForeground": "#DCDCCC",
            "lineHighlight": "#4F4F4F",
            "selectionBackground": "#5F5F5F",
            "cursor": "#DCDCCC",
            "gutterBackground": "#3F3F3F",
            "gutterForeground": "#7F7F7F",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#F0DFAF"),
            "string": TokenStyle(foreground: "#CC9393"),
            "comment": TokenStyle(foreground: "#7F9F7F", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#8CD0D3"),
            "type": TokenStyle(foreground: "#DFAF8F"),
            "function": TokenStyle(foreground: "#EFEF8F"),
            "variable": TokenStyle(foreground: "#DCDCCC"),
            "operator": TokenStyle(foreground: "#F0DFAF"),
            "punctuation": TokenStyle(foreground: "#DCDCCC"),
            "preprocessor": TokenStyle(foreground: "#DFAF8F"),
            "tag": TokenStyle(foreground: "#E89393"),
        ]
    )

    // MARK: - Obsidian

    public static let obsidian = Theme(
        name: "Obsidian",
        type: .dark,
        colors: [
            "editorBackground": "#293134",
            "editorForeground": "#E0E2E4",
            "lineHighlight": "#2F393C",
            "selectionBackground": "#3D4C51",
            "cursor": "#E0E2E4",
            "gutterBackground": "#293134",
            "gutterForeground": "#66747B",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#93C763"),
            "string": TokenStyle(foreground: "#EC7600"),
            "comment": TokenStyle(foreground: "#66747B", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FFCD22"),
            "type": TokenStyle(foreground: "#678CB1"),
            "function": TokenStyle(foreground: "#E0E2E4"),
            "variable": TokenStyle(foreground: "#E0E2E4"),
            "operator": TokenStyle(foreground: "#E8E2B7"),
            "punctuation": TokenStyle(foreground: "#E0E2E4"),
            "preprocessor": TokenStyle(foreground: "#A082BD"),
            "tag": TokenStyle(foreground: "#93C763"),
        ]
    )

    // MARK: - Bespin

    public static let bespin = Theme(
        name: "Bespin",
        type: .dark,
        colors: [
            "editorBackground": "#28211C",
            "editorForeground": "#BAAE9E",
            "lineHighlight": "#322B25",
            "selectionBackground": "#4C4138",
            "cursor": "#A7A7A7",
            "gutterBackground": "#28211C",
            "gutterForeground": "#6E6454",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#CF6A4C"),
            "string": TokenStyle(foreground: "#F9EE98"),
            "comment": TokenStyle(foreground: "#666666", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#CF6A4C"),
            "type": TokenStyle(foreground: "#C5AF75"),
            "function": TokenStyle(foreground: "#937121"),
            "variable": TokenStyle(foreground: "#BAAE9E"),
            "operator": TokenStyle(foreground: "#CF6A4C"),
            "punctuation": TokenStyle(foreground: "#BAAE9E"),
            "preprocessor": TokenStyle(foreground: "#CF6A4C"),
            "tag": TokenStyle(foreground: "#CF6A4C"),
        ]
    )

    // MARK: - Black Board

    public static let blackBoard = Theme(
        name: "Black Board",
        type: .dark,
        colors: [
            "editorBackground": "#0C1021",
            "editorForeground": "#F8F8F8",
            "lineHighlight": "#18192B",
            "selectionBackground": "#253B76",
            "cursor": "#FFFFFFB3",
            "gutterBackground": "#0C1021",
            "gutterForeground": "#555555",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#FBDE2D"),
            "string": TokenStyle(foreground: "#61CE3C"),
            "comment": TokenStyle(foreground: "#AEAEAE", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#D8FA3C"),
            "type": TokenStyle(foreground: "#8DA6CE"),
            "function": TokenStyle(foreground: "#FF6400"),
            "variable": TokenStyle(foreground: "#F8F8F8"),
            "operator": TokenStyle(foreground: "#FBDE2D"),
            "punctuation": TokenStyle(foreground: "#F8F8F8"),
            "preprocessor": TokenStyle(foreground: "#FBDE2D"),
            "tag": TokenStyle(foreground: "#8DA6CE"),
        ]
    )

    // MARK: - Twilight

    public static let twilight = Theme(
        name: "Twilight",
        type: .dark,
        colors: [
            "editorBackground": "#141414",
            "editorForeground": "#F7F7F7",
            "lineHighlight": "#1E1E1E",
            "selectionBackground": "#3C3C3C",
            "cursor": "#A7A7A7",
            "gutterBackground": "#141414",
            "gutterForeground": "#555555",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#CDA869"),
            "string": TokenStyle(foreground: "#8F9D6A"),
            "comment": TokenStyle(foreground: "#5F5A60", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#CF6A4C"),
            "type": TokenStyle(foreground: "#7587A6"),
            "function": TokenStyle(foreground: "#9B703F"),
            "variable": TokenStyle(foreground: "#F7F7F7"),
            "operator": TokenStyle(foreground: "#CDA869"),
            "punctuation": TokenStyle(foreground: "#F7F7F7"),
            "preprocessor": TokenStyle(foreground: "#CDA869"),
            "tag": TokenStyle(foreground: "#CF6A4C"),
        ]
    )

    // MARK: - Vibrant Ink

    public static let vibrantInk = Theme(
        name: "Vibrant Ink",
        type: .dark,
        colors: [
            "editorBackground": "#191919",
            "editorForeground": "#FFFFFF",
            "lineHighlight": "#222222",
            "selectionBackground": "#414141",
            "cursor": "#FFFFFF",
            "gutterBackground": "#191919",
            "gutterForeground": "#666666",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#FF6600"),
            "string": TokenStyle(foreground: "#66FF00"),
            "comment": TokenStyle(foreground: "#9933CC", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FFCC00"),
            "type": TokenStyle(foreground: "#AAAAFF"),
            "function": TokenStyle(foreground: "#FFCC00"),
            "variable": TokenStyle(foreground: "#FFFFFF"),
            "operator": TokenStyle(foreground: "#FF6600"),
            "punctuation": TokenStyle(foreground: "#FFFFFF"),
            "preprocessor": TokenStyle(foreground: "#FF6600"),
            "tag": TokenStyle(foreground: "#AAAAFF"),
        ]
    )

    // MARK: - Ruby Blue

    public static let rubyBlue = Theme(
        name: "Ruby Blue",
        type: .dark,
        colors: [
            "editorBackground": "#112435",
            "editorForeground": "#FFFFFF",
            "lineHighlight": "#1A3040",
            "selectionBackground": "#264059",
            "cursor": "#FFFFFF",
            "gutterBackground": "#112435",
            "gutterForeground": "#4E6E8E",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#FF00FF"),
            "string": TokenStyle(foreground: "#FF9900"),
            "comment": TokenStyle(foreground: "#999999", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FF9900"),
            "type": TokenStyle(foreground: "#88AAFF"),
            "function": TokenStyle(foreground: "#88AAFF"),
            "variable": TokenStyle(foreground: "#FFFFFF"),
            "operator": TokenStyle(foreground: "#FF00FF"),
            "punctuation": TokenStyle(foreground: "#FFFFFF"),
            "preprocessor": TokenStyle(foreground: "#FF00FF"),
            "tag": TokenStyle(foreground: "#88AAFF"),
        ]
    )

    // MARK: - vim Dark Blue

    public static let vimDarkBlue = Theme(
        name: "vim Dark Blue",
        type: .dark,
        colors: [
            "editorBackground": "#00005F",
            "editorForeground": "#FFFFFF",
            "lineHighlight": "#000080",
            "selectionBackground": "#0000A0",
            "cursor": "#FFFF00",
            "gutterBackground": "#00005F",
            "gutterForeground": "#8080FF",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#FFFF00"),
            "string": TokenStyle(foreground: "#FF00FF"),
            "comment": TokenStyle(foreground: "#00FFFF", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FF0000"),
            "type": TokenStyle(foreground: "#00FF00"),
            "function": TokenStyle(foreground: "#FFFFFF"),
            "variable": TokenStyle(foreground: "#FFFFFF"),
            "operator": TokenStyle(foreground: "#FFFF00"),
            "punctuation": TokenStyle(foreground: "#FFFFFF"),
            "preprocessor": TokenStyle(foreground: "#FFFF00"),
            "tag": TokenStyle(foreground: "#00FF00"),
        ]
    )

    // MARK: - Deep Black

    public static let deepBlack = Theme(
        name: "Deep Black",
        type: .dark,
        colors: [
            "editorBackground": "#000000",
            "editorForeground": "#CCCCCC",
            "lineHighlight": "#0A0A0A",
            "selectionBackground": "#333333",
            "cursor": "#CCCCCC",
            "gutterBackground": "#000000",
            "gutterForeground": "#555555",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#93C763"),
            "string": TokenStyle(foreground: "#EC7600"),
            "comment": TokenStyle(foreground: "#66747B", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#FFCD22"),
            "type": TokenStyle(foreground: "#678CB1"),
            "function": TokenStyle(foreground: "#A082BD"),
            "variable": TokenStyle(foreground: "#CCCCCC"),
            "operator": TokenStyle(foreground: "#93C763"),
            "punctuation": TokenStyle(foreground: "#CCCCCC"),
            "preprocessor": TokenStyle(foreground: "#93C763"),
            "tag": TokenStyle(foreground: "#678CB1"),
        ]
    )

    // MARK: - Choco

    public static let choco = Theme(
        name: "Choco",
        type: .dark,
        colors: [
            "editorBackground": "#3B2F2B",
            "editorForeground": "#CCC4B5",
            "lineHighlight": "#453935",
            "selectionBackground": "#5A4A44",
            "cursor": "#CCC4B5",
            "gutterBackground": "#3B2F2B",
            "gutterForeground": "#7A6A5E",
        ],
        tokenColors: [
            "keyword": TokenStyle(foreground: "#C98415"),
            "string": TokenStyle(foreground: "#50AF50"),
            "comment": TokenStyle(foreground: "#706050", fontStyle: "italic"),
            "number": TokenStyle(foreground: "#50AF50"),
            "type": TokenStyle(foreground: "#8CA0D0"),
            "function": TokenStyle(foreground: "#D0C0A0"),
            "variable": TokenStyle(foreground: "#CCC4B5"),
            "operator": TokenStyle(foreground: "#C98415"),
            "punctuation": TokenStyle(foreground: "#CCC4B5"),
            "preprocessor": TokenStyle(foreground: "#C98415"),
            "tag": TokenStyle(foreground: "#8CA0D0"),
        ]
    )

}
