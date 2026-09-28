#if targetEnvironment(simulator)
import TransKeyCore

/// 시뮬레이터 전용 데모 번역.
/// Apple 온디바이스 번역은 시뮬레이터에서 동작하지 않으므로, UI 흐름 확인용으로 작은 사전만 제공한다.
/// 실기기 빌드에는 컴파일되지 않는다.
struct SimulatorDemoProvider: TranslationProvider {
    private static let entries: [(ko: String, en: String, ja: String, es: String)] = [
        ("사과", "apple", "りんご", "manzana"),
        ("안녕하세요", "hello", "こんにちは", "hola"),
        ("감사합니다", "thank you", "ありがとうございます", "gracias"),
        ("사랑", "love", "愛", "amor"),
        ("물", "water", "水", "agua"),
        ("고양이", "cat", "猫", "gato"),
        ("강아지", "puppy", "子犬", "cachorro"),
        ("학교", "school", "学校", "escuela"),
        ("친구", "friend", "友達", "amigo"),
        ("커피", "coffee", "コーヒー", "café"),
        ("오늘", "today", "今日", "hoy"),
        ("행복", "happiness", "幸せ", "felicidad"),
        ("바다", "sea", "海", "mar"),
        ("책", "book", "本", "libro"),
        ("사람", "person", "人", "persona")
    ]

    func translate(_ text: String, from source: Language?, to targets: [Language]) async throws -> [Language: String] {
        let key = text.lowercased()
        guard let entry = Self.entries.first(where: { $0.ko == key || $0.en == key }) else {
            throw TranslationError.unsupported
        }
        var result: [Language: String] = [:]
        for target in targets {
            switch target {
            case .korean: result[target] = entry.ko
            case .english: result[target] = entry.en
            case .japanese: result[target] = entry.ja
            case .spanish: result[target] = entry.es
            }
        }
        return result
    }
}
#endif
