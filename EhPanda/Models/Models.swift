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
    static let empty = Gallery(
        gid: "",
        token: "",
        title: "",
        rating: 0,
        tags: [],
        category: .nonH,
        uploader: nil,
        postedDate: Date(),
        coverURL: "",
        galleryURL: ""
    )

    static let preview = Gallery(
        gid: "",
        token: "",
        title: "Preview",
        rating: 3.5,
        tags: [],
        category: .doujinshi,
        language: .Japanese,
        uploader: "Anonymous",
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
    var pageCount: Int?
    let postedDate: Date
    let coverURL: String
    let galleryURL: String
    var lastOpenDate: Date?
}

struct GalleryDetail: Codable {
    static let empty = GalleryDetail(
        gid: "",
        title: "",
        isFavored: false,
        isVisible: true,
        rating: 0.0,
        userRating: 0.0,
        ratingCount: 0,
        category: .nonH,
        language: .English,
        uploader: "",
        postedDate: .distantPast,
        coverURL: "",
        favoredCount: 0,
        pageCount: 0,
        sizeCount: 0,
        sizeType: "",
        torrentCount: 0
    )

    static let preview = GalleryDetail(
        gid: "",
        title: "Preview",
        jpnTitle: "プレビュー",
        isFavored: true,
        isVisible: true,
        rating: 3.5,
        userRating: 4.0,
        ratingCount: 1919,
        category: .doujinshi,
        language: .Japanese,
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
    var isVisible: Bool
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
    var id: String { category.rawValue }

    let category: TagCategory
    let content: [String]
}

struct GalleryComment: Identifiable, Codable {
    var id: String { author + formattedDateString }

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
        language.languageAbbr
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
        Color(galleryHost.rawValue + "/" + rawValue)
    }
    var value: Int {
        switch self {
        case .doujinshi:
            return 2
        case .gallery:
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
    var languageAbbr: String {
        switch self {
        // swiftlint:disable switch_case_alignment line_length
        case .Other: return "N/A"

        case .Afrikaans: return "AF"; case .Albanian: return "SQ"; case .Arabic: return "AR"

        case .Bengali: return "BN"; case .Bosnian: return "BS"; case .Bulgarian: return "BG"; case .Burmese: return "MY"

        case .Catalan: return "CA"; case .Cebuano: return "CEB"; case .Chinese: return "ZH"; case .Croatian: return "HR"; case .Czech: return "CS"

        case .Danish: return "DA"; case .Dutch: return "NL"

        case .English: return "EN"; case .Esperanto: return "EO"; case .Estonian: return "ET"

        case .Finnish: return "FI"; case .French: return "FR"

        case .Georgian: return "KA"; case .German: return "DE"; case .Greek: return "EL"

        case .Hebrew: return "HE"; case .Hindi: return "HI"; case .Hmong: return "HMN"; case .Hungarian: return "HU"

        case .Indonesian: return "ID"; case .Italian: return "IT"

        case .Japanese: return "JA"

        case .Kazakh: return "KK"; case .Khmer: return "KM"; case .Korean: return "KO"; case .Kurdish: return "KU"

        case .Lao: return "LO"; case .Latin: return "LA"

        case .Mongolian: return "MN"

        case .Ndebele: return "ND"; case .Nepali: return "NE"; case .Norwegian: return "NO"

        case .Oromo: return "OM"

        case .Pashto: return "PS"; case .Persian: return "FA"; case .Polish: return "PL"; case .Portuguese: return "PT"; case .Punjabi: return "PA"

        case .Romanian: return "RO"; case .Russian: return "RU"

        case .Sango: return "SG"; case .Serbian: return "SR"; case .Shona: return "SN"; case .Slovak: return "SK"; case .Slovenian: return "SL"; case .Somali: return "SO"; case .Spanish: return "ES"; case .Swahili: return "SW"; case .Swedish: return "SV"

        case .Tagalog: return "TL"; case .Thai: return "TH"; case .Tigrinya: return "TI"; case .Turkish: return "TR"

        case .Ukrainian: return "UK"; case .Urdu: return "UR"

        case .Vietnamese: return "VI"

        case .Zulu: return "ZU"
        // swiftlint:enable switch_case_alignment line_length
        }
    }
}

// MARK: Enums
enum Category: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case doujinshi = "Doujinshi"
    case gallery = "Gallery"
    case artistCG = "Artist CG"
    case gameCG = "Game CG"
    case western = "Western"
    case nonH = "Non-H"
    case imageSet = "Image Set"
    case cosplay = "Cosplay"
    case asianPorn = "Asian Porn"
    case misc = "Misc"
}

enum TagCategory: String, Codable {
    case reclass = "Reclass"
    case language = "Language"
    case parody = "Parody"
    case character = "Character"
    case group = "Group"
    case artist = "Artist"
    case male = "Male"
    case female = "Female"
    case misc = "Misc"
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

enum PreviewConfig: Codable {
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
            return Defaults.URL
                .ehTagTranslationJpnRepo
        case .simplifiedChinese,
             .traditionalChinese:
            return Defaults.URL
                .ehTagTrasnlationRepo
        }
    }
    var remoteFilename: String {
        switch self {
        case .japanese:
            return "jpn_text.json"
        case .simplifiedChinese,
                .traditionalChinese:
            return "db.text.json"
        }
    }
    var checkUpdateLink: String {
        Defaults.URL.githubAPI(
            repoName: repoName
        )
    }
    var downloadLink: String {
        Defaults.URL.githubDownload(
            repoName: repoName,
            fileName: remoteFilename
        )
    }
}

enum Language: String, Codable {
    // swiftlint:disable identifier_name line_length
    case Other = "N/A"

    case Afrikaans = "Afrikaans"; case Albanian = "Albanian"; case Arabic = "Arabic"

    case Bengali = "Bengali"; case Bosnian = "Bosnian"; case Bulgarian = "Bulgarian"; case Burmese = "Burmese"

    case Catalan = "Catalan"; case Cebuano = "Cebuano"; case Chinese = "Chinese"; case Croatian = "Croatian"; case Czech = "Czech"

    case Danish = "Danish"; case Dutch = "Dutch"

    case English = "English"; case Esperanto = "Esperanto"; case Estonian = "Estonian"

    case Finnish = "Finnish"; case French = "French"

    case Georgian = "Georgian"; case German = "German"; case Greek = "Greek"

    case Hebrew = "Hebrew"; case Hindi = "Hindi"; case Hmong = "Hmong"; case Hungarian = "Hungarian"

    case Indonesian = "Indonesian"; case Italian = "Italian"

    case Japanese = "Japanese"

    case Kazakh = "Kazakh"; case Khmer = "Khmer"; case Korean = "Korean"; case Kurdish = "Kurdish"

    case Lao = "Lao"; case Latin = "Latin"

    case Mongolian = "Mongolian"

    case Ndebele = "Ndebele"; case Nepali = "Nepali"; case Norwegian = "Norwegian"

    case Oromo = "Oromo"

    case Pashto = "Pashto"; case Persian = "Persian"; case Polish = "Polish"; case Portuguese = "Portuguese"; case Punjabi = "Punjabi"

    case Romanian = "Romanian"; case Russian = "Russian"

    case Sango = "Sango"; case Serbian = "Serbian"; case Shona = "Shona"; case Slovak = "Slovak"; case Slovenian = "Slovenian"; case Somali = "Somali"; case Spanish = "Spanish"; case Swahili = "Swahili"; case Swedish = "Swedish"

    case Tagalog = "Tagalog"; case Thai = "Thai"; case Tigrinya = "Tigrinya"; case Turkish = "Turkish"

    case Ukrainian = "Ukrainian"; case Urdu = "Urdu"

    case Vietnamese = "Vietnamese"

    case Zulu = "Zulu"
    // swiftlint:enable identifier_name line_length
}
