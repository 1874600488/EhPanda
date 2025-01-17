//
//  Models.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/11/22.
//

import SwiftUI

// MARK: Protocols
protocol DateFormattable {
    var originalDate: Date { get }
}
extension DateFormattable {
    var formattedDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        formatter.calendar = Calendar.current
        return formatter.string(from: originalDate)
    }
}

// MARK: Structs
struct Gallery: Identifiable, Codable, Equatable {
    static func == (lhs: Gallery, rhs: Gallery) -> Bool {
        lhs.gid == rhs.gid
    }

    static let preview = Gallery(
        gid: "",
        token: "",
        title: "Preview",
        rating: 3.5,
        tags: [],
        category: .doujinshi,
        language: .japanese,
        uploader: "Anonymous",
        pageCount: 0,
        postedDate: .now,
        coverURL: "https://github.com/"
            + "tatsuz0u/Imageset/blob/"
            + "main/JPGs/2.jpg?raw=true",
        galleryURL: ""
    )

    var id: String { gid }
    let gid: String
    let token: String

    var title: String
    var rating: Float
    var tags: [String]
    let category: Category
    var language: Language?
    let uploader: String?
    var pageCount: Int
    let postedDate: Date
    let coverURL: String
    let galleryURL: String
    var lastOpenDate: Date?
}

struct GalleryDetail: Codable {
    static let preview = GalleryDetail(
        gid: "",
        title: "Preview",
        jpnTitle: "プレビュー",
        isFavored: true,
        visibility: .yes,
        rating: 3.5,
        userRating: 4.0,
        ratingCount: 1919,
        category: .doujinshi,
        language: .japanese,
        uploader: "Anonymous",
        postedDate: .distantPast,
        coverURL: "https://github.com/"
        + "tatsuz0u/Imageset/blob/"
        + "main/JPGs/2.jpg?raw=true",
        favoredCount: 514,
        pageCount: 114,
        sizeCount: 514,
        sizeType: "MB",
        torrentCount: 101
    )

    let gid: String
    var title: String
    var jpnTitle: String?
    var isFavored: Bool
    var visibility: GalleryVisibility
    var rating: Float
    var userRating: Float
    var ratingCount: Int
    let category: Category
    let language: Language
    let uploader: String
    let postedDate: Date
    let coverURL: String
    var archiveURL: String?
    var parentURL: String?
    var favoredCount: Int
    var pageCount: Int
    var sizeCount: Float
    var sizeType: String
    var torrentCount: Int
}

struct GalleryState: Codable {
    static let empty = GalleryState(gid: "")
    static let preview = GalleryState(gid: "")

    let gid: String
    var tags = [GalleryTag]()
    var readingProgress = 0
    var previews = [Int: String]()
    var previewConfig: PreviewConfig?
    var comments = [GalleryComment]()
    var contents = [Int: String]()
    var originalContents = [Int: String]()
    var thumbnails = [Int: String]()
}

struct GalleryArchive: Codable {
    struct HathArchive: Codable, Identifiable {
        var id: String { resolution.rawValue }

        let resolution: ArchiveRes
        let fileSize: String
        let gpPrice: String
    }

    let hathArchives: [HathArchive]
}

struct GalleryTag: Codable, Identifiable {
    var id: String { namespace }

    let namespace: String
    let content: [String]
    let category: TagCategory?

    init(namespace: String = "other", content: [String]) {
        self.namespace = namespace
        self.content = content
        self.category = TagCategory(rawValue: namespace)
    }
}

struct GalleryComment: Identifiable, Codable {
    var id: String { commentID }

    var votedUp: Bool
    var votedDown: Bool
    let votable: Bool
    let editable: Bool

    let score: String?
    let author: String
    let contents: [CommentContent]
    let commentID: String
    let commentDate: Date
}

struct CommentContent: Identifiable, Codable {
    var id: String {
        [
            "\(type.rawValue)",
            text, link, imgURL,
            secondLink, secondImgURL
        ]
        .compactMap({$0}).joined()
    }

    let type: CommentContentType
    var text: String?
    var link: String?
    var imgURL: String?

    var secondLink: String?
    var secondImgURL: String?
}

struct GalleryTorrent: Identifiable, Codable {
    var id: String { uploader + formattedDateString }

    let postedDate: Date
    let fileSize: String
    let seedCount: Int
    let peerCount: Int
    let downloadCount: Int
    let uploader: String
    let fileName: String
    let hash: String
    let torrentURL: String
}

struct Log: Identifiable, Comparable {
    static func < (lhs: Log, rhs: Log) -> Bool {
        lhs.fileName < rhs.fileName
    }

    var id: String { fileName }
    let fileName: String
    let contents: [String]
}

// MARK: Computed Properties
extension Gallery: DateFormattable, CustomStringConvertible {
    var description: String {
        "Gallery(\(gid))"
    }

    var filledCount: Int { Int(rating) }
    var halfFilledCount: Int { Int(rating - 0.5) == filledCount ? 1 : 0 }
    var notFilledCount: Int { 5 - filledCount - halfFilledCount }

    var color: Color {
        category.color
    }
    var originalDate: Date {
        postedDate
    }
}

extension GalleryDetail: DateFormattable, CustomStringConvertible {
    var description: String {
        "GalleryDetail(gid: \(gid), \(jpnTitle ?? title))"
    }

    var languageAbbr: String {
        language.abbreviation
    }
    var originalDate: Date {
        postedDate
    }
}

extension GalleryState: CustomStringConvertible {
    var description: String {
        "GalleryState(gid: \(gid), tags: \(tags.count), "
        + "previews: \(previews.count), comments: \(comments.count))"
    }
}

extension GalleryComment: DateFormattable {
    var originalDate: Date {
        commentDate
    }
}

extension GalleryTorrent: DateFormattable, CustomStringConvertible {
    var description: String {
        "GalleryTorrent(\(fileName))"
    }
    var originalDate: Date {
        postedDate
    }
    var magnetURL: String {
        Defaults.URL.magnet(hash: hash)
    }
}

extension Category {
    var color: Color {
        Color(AppUtil.galleryHost.rawValue + "/" + rawValue)
    }
    var value: Int {
        switch self {
        case .doujinshi:
            return 2
        case .manga:
            return 4
        case .artistCG:
            return 8
        case .gameCG:
            return 16
        case .western:
            return 512
        case .nonH:
            return 256
        case .imageSet:
            return 32
        case .cosplay:
            return 64
        case .asianPorn:
            return 128
        case .misc:
            return 1
        }
    }
}

extension Language {
    var name: String {
        switch self {
        case .other:
            return "LANGUAGE_OTHER"
        case .invalid:
            return "LANGUAGE_INVALID"
        default:
            return rawValue
        }
    }
    var abbreviation: String {
        switch self {
        // swiftlint:disable switch_case_alignment line_length
        case .invalid: return "N/A" case .other: return "N/A"; case .afrikaans: return "AF"; case .albanian: return "SQ"; case .arabic: return "AR"; case .bengali: return "BN"; case .bosnian: return "BS"; case .bulgarian: return "BG"; case .burmese: return "MY"; case .catalan: return "CA"; case .cebuano: return "CEB"; case .chinese: return "ZH"; case .croatian: return "HR"; case .czech: return "CS"; case .danish: return "DA"; case .dutch: return "NL"; case .english: return "EN"; case .esperanto: return "EO"; case .estonian: return "ET"; case .finnish: return "FI"; case .french: return "FR"; case .georgian: return "KA"; case .german: return "DE"; case .greek: return "EL"; case .hebrew: return "HE"; case .hindi: return "HI"; case .hmong: return "HMN"; case .hungarian: return "HU"; case .indonesian: return "ID"; case .italian: return "IT"; case .japanese: return "JA"; case .kazakh: return "KK"; case .khmer: return "KM"; case .korean: return "KO"; case .kurdish: return "KU"; case .lao: return "LO"; case .latin: return "LA"; case .mongolian: return "MN"; case .ndebele: return "ND"; case .nepali: return "NE"; case .norwegian: return "NO"; case .oromo: return "OM"; case .pashto: return "PS"; case .persian: return "FA"; case .polish: return "PL"; case .portuguese: return "PT"; case .punjabi: return "PA"; case .romanian: return "RO"; case .russian: return "RU"; case .sango: return "SG"; case .serbian: return "SR"; case .shona: return "SN"; case .slovak: return "SK"; case .slovenian: return "SL"; case .somali: return "SO"; case .spanish: return "ES"; case .swahili: return "SW"; case .swedish: return "SV"; case .tagalog: return "TL"; case .thai: return "TH"; case .tigrinya: return "TI"; case .turkish: return "TR"; case .ukrainian: return "UK"; case .urdu: return "UR"; case .vietnamese: return "VI"; case .zulu: return "ZU"
        // swiftlint:enable switch_case_alignment line_length
        }
    }
}

// MARK: Enums
enum Category: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case doujinshi = "Doujinshi"
    case manga = "Manga"
    case artistCG = "Artist CG"
    case gameCG = "Game CG"
    case western = "Western"
    case nonH = "Non-H"
    case imageSet = "Image Set"
    case cosplay = "Cosplay"
    case asianPorn = "Asian Porn"
    case misc = "Misc"
}

enum TagCategory: String, Codable, CaseIterable {
    case reclass
    case language
    case parody
    case character
    case group
    case artist
    case male
    case female
    case mixed
    case cosplayer
    case other
    case temp
}

enum GalleryVisibility: Codable, Equatable {
    case yes
    case no(reason: String)
}

extension GalleryVisibility {
    var value: String {
        switch self {
        case .yes:
            return "Yes"
        case .no(let reason):
            return "No".localized
            + " (\(reason.localized))"
        }
    }
}

enum ArchiveRes: String, Codable, CaseIterable {
    case x780 = "780x"
    case x980 = "980x"
    case x1280 = "1280x"
    case x1600 = "1600x"
    case x2400 = "2400x"
    case original = "Original"
}

extension ArchiveRes {
    var name: String {
        switch self {
        case .x780, .x980, .x1280, .x1600, .x2400:
            return rawValue
        case .original:
            return "ARCHIVE_RESOLUTION_ORIGINAL"
        }
    }
    var param: String {
        switch self {
        case .original:
            return "org"
        default:
            return String(rawValue.dropLast())
        }
    }
}

enum CommentContentType: Int, Codable {
    case singleImg
    case doubleImg
    case linkedImg
    case doubleLinkedImg

    case plainText
    case linkedText

    case singleLink
}

enum PreviewConfig: Codable, Equatable {
    case normal(rows: Int)
    case large(rows: Int)
}

extension PreviewConfig {
    var batchSize: Int {
        switch self {
        case .normal(let rows):
            return 10 * rows
        case .large(let rows):
            return 5 * rows
        }
    }

    func pageNumber(index: Int) -> Int {
        index / batchSize
    }
    func batchRange(index: Int) -> ClosedRange<Int> {
        let lowerBound = pageNumber(index: index) * batchSize + 1
        let upperBound = lowerBound + batchSize - 1
        return lowerBound...upperBound
    }
}

enum TranslatableLanguage: Codable, CaseIterable {
    case japanese
    case simplifiedChinese
    case traditionalChinese
}

extension TranslatableLanguage {
    var languageCode: String {
        switch self {
        case .japanese:
            return "ja"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }
    var repoName: String {
        switch self {
        case .japanese:
            return Defaults.URL.ehTagTranslationJpnRepo
        case .simplifiedChinese,
             .traditionalChinese:
            return Defaults.URL.ehTagTrasnlationRepo
        }
    }
    var remoteFilename: String {
        switch self {
        case .japanese:
            return "jpn_text.json"
        case .simplifiedChinese, .traditionalChinese:
            return "db.text.json"
        }
    }
    var checkUpdateLink: String {
        Defaults.URL.githubAPI(
            repoName: repoName
        )
    }
    var downloadLink: String {
        Defaults.URL.githubDownload(repoName: repoName, fileName: remoteFilename)
    }
}

enum Language: String, Codable {
    // swiftlint:disable line_length
    case invalid = "N/A"; case other = "Other"; case afrikaans = "Afrikaans"; case albanian = "Albanian"; case arabic = "Arabic"; case bengali = "Bengali"; case bosnian = "Bosnian"; case bulgarian = "Bulgarian"; case burmese = "Burmese"; case catalan = "Catalan"; case cebuano = "Cebuano"; case chinese = "Chinese"; case croatian = "Croatian"; case czech = "Czech"; case danish = "Danish"; case dutch = "Dutch"; case english = "English"; case esperanto = "Esperanto"; case estonian = "Estonian"; case finnish = "Finnish"; case french = "French"; case georgian = "Georgian"; case german = "German"; case greek = "Greek"; case hebrew = "Hebrew"; case hindi = "Hindi"; case hmong = "Hmong"; case hungarian = "Hungarian"; case indonesian = "Indonesian"; case italian = "Italian"; case japanese = "Japanese"; case kazakh = "Kazakh"; case khmer = "Khmer"; case korean = "Korean"; case kurdish = "Kurdish"; case lao = "Lao"; case latin = "Latin"; case mongolian = "Mongolian"; case ndebele = "Ndebele"; case nepali = "Nepali"; case norwegian = "Norwegian"; case oromo = "Oromo"; case pashto = "Pashto"; case persian = "Persian"; case polish = "Polish"; case portuguese = "Portuguese"; case punjabi = "Punjabi"; case romanian = "Romanian"; case russian = "Russian"; case sango = "Sango"; case serbian = "Serbian"; case shona = "Shona"; case slovak = "Slovak"; case slovenian = "Slovenian"; case somali = "Somali"; case spanish = "Spanish"; case swahili = "Swahili"; case swedish = "Swedish"; case tagalog = "Tagalog"; case thai = "Thai"; case tigrinya = "Tigrinya"; case turkish = "Turkish"; case ukrainian = "Ukrainian"; case urdu = "Urdu"; case vietnamese = "Vietnamese"; case zulu = "Zulu"
    // swiftlint:enable line_length
}
