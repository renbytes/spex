import Foundation

/// A utility for creating the ASCII art banner.
struct Banner {

    /// Generates the `spex` ASCII art banner as a string.
    ///
    /// This function constructs the multi-line ASCII art logo. It's designed to be
    /// printed before the main help text of the command-line tool.
    ///
    /// - Returns: A multi-line string containing the banner.
    static func make() -> String {
        let banner = [
            ",adPPYba,  8b,dPPYba,    ,adPPYba,  8b,     ,d8  ",
            "I8[    \"\"  88P'    \"8a  a8P_____88   `Y8, ,8P'   ",
            " `\"Y8ba,   88       d8  8PP\"\"\"\"\"\"\"     )888(     ",
            "aa    ]8I  88b,   ,a8\"  \"8b,   ,aa   ,d8\" \"8b,   ",
            "`\"YbbdP\"'  88`YbbdP\"'    `\"Ybbd8\"'  8P'     `Y8  ",
            "           88                                      ",
            "           88                                      ",
        ]
        return banner.joined(separator: "\n")
    }
}
