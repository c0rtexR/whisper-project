import Foundation

struct WhisperLanguage: Identifiable {
    let code: String
    let name: String

    var id: String { code }

    static let autoDetect = WhisperLanguage(code: "auto", name: "Auto-detect")

    static let common: [WhisperLanguage] = [
        WhisperLanguage(code: "en", name: "English"),
        WhisperLanguage(code: "zh", name: "Chinese"),
        WhisperLanguage(code: "de", name: "German"),
        WhisperLanguage(code: "es", name: "Spanish"),
        WhisperLanguage(code: "ru", name: "Russian"),
        WhisperLanguage(code: "ko", name: "Korean"),
        WhisperLanguage(code: "fr", name: "French"),
        WhisperLanguage(code: "ja", name: "Japanese"),
        WhisperLanguage(code: "pt", name: "Portuguese"),
        WhisperLanguage(code: "tr", name: "Turkish"),
        WhisperLanguage(code: "pl", name: "Polish"),
        WhisperLanguage(code: "it", name: "Italian"),
        WhisperLanguage(code: "nl", name: "Dutch"),
        WhisperLanguage(code: "ar", name: "Arabic"),
        WhisperLanguage(code: "hi", name: "Hindi"),
    ]

    static let others: [WhisperLanguage] = [
        WhisperLanguage(code: "af", name: "Afrikaans"),
        WhisperLanguage(code: "az", name: "Azerbaijani"),
        WhisperLanguage(code: "be", name: "Belarusian"),
        WhisperLanguage(code: "bg", name: "Bulgarian"),
        WhisperLanguage(code: "bn", name: "Bengali"),
        WhisperLanguage(code: "bs", name: "Bosnian"),
        WhisperLanguage(code: "ca", name: "Catalan"),
        WhisperLanguage(code: "cs", name: "Czech"),
        WhisperLanguage(code: "cy", name: "Welsh"),
        WhisperLanguage(code: "da", name: "Danish"),
        WhisperLanguage(code: "el", name: "Greek"),
        WhisperLanguage(code: "et", name: "Estonian"),
        WhisperLanguage(code: "fa", name: "Persian"),
        WhisperLanguage(code: "fi", name: "Finnish"),
        WhisperLanguage(code: "gl", name: "Galician"),
        WhisperLanguage(code: "gu", name: "Gujarati"),
        WhisperLanguage(code: "ha", name: "Hausa"),
        WhisperLanguage(code: "haw", name: "Hawaiian"),
        WhisperLanguage(code: "he", name: "Hebrew"),
        WhisperLanguage(code: "hr", name: "Croatian"),
        WhisperLanguage(code: "hu", name: "Hungarian"),
        WhisperLanguage(code: "hy", name: "Armenian"),
        WhisperLanguage(code: "id", name: "Indonesian"),
        WhisperLanguage(code: "is", name: "Icelandic"),
        WhisperLanguage(code: "jw", name: "Javanese"),
        WhisperLanguage(code: "ka", name: "Georgian"),
        WhisperLanguage(code: "kk", name: "Kazakh"),
        WhisperLanguage(code: "km", name: "Khmer"),
        WhisperLanguage(code: "kn", name: "Kannada"),
        WhisperLanguage(code: "la", name: "Latin"),
        WhisperLanguage(code: "lb", name: "Luxembourgish"),
        WhisperLanguage(code: "ln", name: "Lingala"),
        WhisperLanguage(code: "lo", name: "Lao"),
        WhisperLanguage(code: "lt", name: "Lithuanian"),
        WhisperLanguage(code: "lv", name: "Latvian"),
        WhisperLanguage(code: "mg", name: "Malagasy"),
        WhisperLanguage(code: "mi", name: "Maori"),
        WhisperLanguage(code: "mk", name: "Macedonian"),
        WhisperLanguage(code: "ml", name: "Malayalam"),
        WhisperLanguage(code: "mn", name: "Mongolian"),
        WhisperLanguage(code: "mr", name: "Marathi"),
        WhisperLanguage(code: "ms", name: "Malay"),
        WhisperLanguage(code: "mt", name: "Maltese"),
        WhisperLanguage(code: "my", name: "Myanmar"),
        WhisperLanguage(code: "ne", name: "Nepali"),
        WhisperLanguage(code: "no", name: "Norwegian"),
        WhisperLanguage(code: "nn", name: "Nynorsk"),
        WhisperLanguage(code: "oc", name: "Occitan"),
        WhisperLanguage(code: "pa", name: "Punjabi"),
        WhisperLanguage(code: "ps", name: "Pashto"),
        WhisperLanguage(code: "ro", name: "Romanian"),
        WhisperLanguage(code: "sa", name: "Sanskrit"),
        WhisperLanguage(code: "sd", name: "Sindhi"),
        WhisperLanguage(code: "si", name: "Sinhala"),
        WhisperLanguage(code: "sk", name: "Slovak"),
        WhisperLanguage(code: "sl", name: "Slovenian"),
        WhisperLanguage(code: "sn", name: "Shona"),
        WhisperLanguage(code: "so", name: "Somali"),
        WhisperLanguage(code: "sq", name: "Albanian"),
        WhisperLanguage(code: "sr", name: "Serbian"),
        WhisperLanguage(code: "su", name: "Sundanese"),
        WhisperLanguage(code: "sv", name: "Swedish"),
        WhisperLanguage(code: "sw", name: "Swahili"),
        WhisperLanguage(code: "ta", name: "Tamil"),
        WhisperLanguage(code: "te", name: "Telugu"),
        WhisperLanguage(code: "tg", name: "Tajik"),
        WhisperLanguage(code: "th", name: "Thai"),
        WhisperLanguage(code: "tk", name: "Turkmen"),
        WhisperLanguage(code: "tl", name: "Tagalog"),
        WhisperLanguage(code: "tt", name: "Tatar"),
        WhisperLanguage(code: "uk", name: "Ukrainian"),
        WhisperLanguage(code: "ur", name: "Urdu"),
        WhisperLanguage(code: "uz", name: "Uzbek"),
        WhisperLanguage(code: "vi", name: "Vietnamese"),
        WhisperLanguage(code: "yo", name: "Yoruba"),
        WhisperLanguage(code: "yue", name: "Cantonese"),
    ]

    static func name(for code: String) -> String {
        if code == "auto" { return "Auto-detect" }
        if let lang = common.first(where: { $0.code == code }) { return lang.name }
        if let lang = others.first(where: { $0.code == code }) { return lang.name }
        return code
    }
}
