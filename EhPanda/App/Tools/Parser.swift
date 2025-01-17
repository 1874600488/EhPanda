//
//  Parser.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import UIKit

struct Parser {
    // MARK: List
    static func parseListItems(doc: HTMLDocument) throws -> [Gallery] {
        func parseCoverURL(node: XMLElement?) throws -> String {
            guard let node = node?.at_xpath("//div [@class='glthumb']")?.at_css("img")
            else { throw AppError.parseFailed }

            var coverURL = node["data-src"]
            if coverURL == nil { coverURL = node["src"] }

            guard let url = coverURL
            else { throw AppError.parseFailed }

            return url
        }

        func parsePublishedTime(node: XMLElement?) throws -> String {
            guard var text = node?.at_xpath("//div [@onclick]")?.text
            else { throw AppError.parseFailed }

            if !text.contains(":") {
                guard let content = node?.text,
                      let range = content.range(of: "pages")
                else { throw AppError.parseFailed }

                text = String(content[range.upperBound...])
            }

            return text
        }

        func parseTagsAndLang(node: XMLElement?) throws -> ([String], Language?) {
            guard let object = node?.xpath("//div [@class='gt']")
            else { throw AppError.parseFailed }

            var tags = [String]()
            var language: Language?
            for tagLink in object {
                if tagLink["title"]?.contains("language") == true {
                    if let langText = tagLink.text?.firstLetterCapitalized,
                       let lang = Language(rawValue: langText)
                    {
                        language = lang
                    }
                }
                if let tagText = tagLink.text {
                    if let style = tagLink["style"],
                       let rangeA = style.range(of: "background:radial-gradient(#"),
                       let rangeB = style.range(of: ",#")
                    {
                        let hex = style[rangeA.upperBound..<rangeB.lowerBound]
                        let wrappedHex = Defaults.ParsingMark.hexStart
                            + hex + Defaults.ParsingMark.hexEnd
                        tags.append(tagText + wrappedHex)
                    } else {
                        tags.append(tagText)
                    }
                }
            }
            return (tags, language)
        }

        func parsePageCount(node: XMLElement?) throws -> Int {
            guard let object = node?.at_xpath("//div [@class='glthumb']")
            else { throw AppError.parseFailed }

            for link in object.xpath("//div")
            where link.text?.contains(" pages") == true
            {
                guard let pageCount = Int(
                    link.text?.replacingOccurrences(
                            of: " pages", with: ""
                    ) ?? ""
                )
                else { continue }

                return pageCount
            }

            throw AppError.parseFailed
        }

        func parseUploader(node: XMLElement?) throws -> String? {
            guard let divNode = node?.at_xpath("//td [@class='gl4c glhide']")?.at_xpath("//div") else {
                throw AppError.parseFailed
            }

            if let aText = divNode.at_xpath("//a")?.text {
                return aText
            } else {
                return divNode.text
            }
        }

        var galleryItems = [Gallery]()
        for link in doc.xpath("//tr") {
            let uploader = try? parseUploader(node: link)
            guard let gl2cNode = link.at_xpath("//td [@class='gl2c']"),
                  let gl3cNode = link.at_xpath("//td [@class='gl3c glname']"),
                  let (rating, _, _) = try? parseRating(node: gl2cNode),
                  let coverURL = try? parseCoverURL(node: gl2cNode),
                  let pageCount = try? parsePageCount(node: gl2cNode),
                  let (tags, language) = try? parseTagsAndLang(node: gl3cNode),
                  let publishedTime = try? parsePublishedTime(node: gl2cNode),
                  let title = link.at_xpath("//div [@class='glink']")?.text,
                  let galleryURL = link.at_xpath("//td [@class='gl3c glname'] //a")?["href"],
                  let postedDate = try? parseDate(time: publishedTime, format: Defaults.DateFormat.publish),
                  let category = Category(rawValue: link.at_xpath("//td [@class='gl1c glcat'] //div")?.text ?? ""),
                  let url = URL(string: galleryURL), url.pathComponents.count >= 4
            else { continue }

            galleryItems.append(
                Gallery(
                    gid: url.pathComponents[2],
                    token: url.pathComponents[3],
                    title: title,
                    rating: rating,
                    tags: tags,
                    category: category,
                    language: language,
                    uploader: uploader,
                    pageCount: pageCount,
                    postedDate: postedDate,
                    coverURL: coverURL,
                    galleryURL: galleryURL
                )
            )
        }

        if galleryItems.isEmpty, let banInterval = parseBanInterval(doc: doc) {
            throw AppError.ipBanned(interval: banInterval)
        }

        return galleryItems
    }

    // MARK: Detail
    static func parseGalleryURL(doc: HTMLDocument) throws -> String {
        guard let galleryURL = doc.at_xpath("//div [@class='sb']")?
                .at_xpath("//a")?["href"] else { throw AppError.parseFailed }
        return galleryURL
    }
    static func parseGalleryDetail(doc: HTMLDocument, gid: String) throws -> (GalleryDetail, GalleryState) {
        func parsePreviewConfig(doc: HTMLDocument) throws -> PreviewConfig {
            guard let previewMode = try? parsePreviewMode(doc: doc),
                  let gdoNode = doc.at_xpath("//div [@id='gdo']"),
                  let rows = gdoNode.at_xpath("//div [@id='gdo2']")?.xpath("//div")
            else { throw AppError.parseFailed }

            for rowLink in rows where rowLink.className == "ths nosel" {
                guard let rowsCount = Int(
                    rowLink.text?.replacingOccurrences(
                        of: " rows", with: "") ?? ""
                ) else { throw AppError.parseFailed }

                if previewMode == "gdtl" {
                    return .large(rows: rowsCount)
                } else {
                    return .normal(rows: rowsCount)
                }
            }
            throw AppError.parseFailed
        }

        func parseCoverURL(node: XMLElement?) throws -> String {
            guard let coverHTML = node?.at_xpath("//div [@id='gd1']")?.innerHTML,
            let rangeA = coverHTML.range(of: "url("),
            let rangeB = coverHTML.range(of: ")")
            else { throw AppError.parseFailed }

            return String(coverHTML[rangeA.upperBound..<rangeB.lowerBound])
        }

        func parseTags(node: XMLElement?) throws -> [GalleryTag] {
            guard let object = node?.xpath("//tr")
            else { throw AppError.parseFailed }

            var tags = [GalleryTag]()
            for link in object {
                guard let category = link
                        .at_xpath("//td [@class='tc']")?
                        .text?.replacingOccurrences(of: ":", with: "")
                else { continue }

                var content = [String]()
                for aLink in link.xpath("//a") {
                    guard let aText = aLink.text
                    else { continue }

                    var fixedText: String?
                    if let range = aText.range(of: "|") {
                        fixedText = String(aText[..<range.lowerBound])
                    }
                    content.append(fixedText ?? aText)
                }

                tags.append(GalleryTag(namespace: category, content: content))
            }

            return tags
        }

        func parseArcAndTor(node: XMLElement?) throws -> (String?, Int) {
            guard let node = node else { throw AppError.parseFailed }

            var archiveURL: String?
            for g2gspLink in node.xpath("//p [@class='g2 gsp']") {
                if archiveURL == nil {
                    archiveURL = try? parseArchiveURL(node: g2gspLink)
                } else {
                    break
                }
            }

            var tmpTorrentCount: Int?
            for g2Link in node.xpath("//p [@class='g2']") {
                if let aText = g2Link.at_xpath("//a")?.text,
                   let rangeA = aText.range(of: "Torrent Download ("),
                   let rangeB = aText.range(of: ")")
                {
                    tmpTorrentCount = Int(aText[rangeA.upperBound..<rangeB.lowerBound])
                }
                if archiveURL == nil {
                    archiveURL = try? parseArchiveURL(node: g2Link)
                }
            }

            guard let torrentCount = tmpTorrentCount
            else { throw AppError.parseFailed }

            return (archiveURL, torrentCount)
        }

        func parseInfoPanel(node: XMLElement?) throws -> [String] {
            guard let object = node?.xpath("//tr")
            else { throw AppError.parseFailed }

            var infoPanel = Array(
                repeating: "",
                count: 8
            )
            for gddLink in object {
                guard let gdt1Text = gddLink.at_xpath("//td [@class='gdt1']")?.text,
                      let gdt2Text = gddLink.at_xpath("//td [@class='gdt2']")?.text
                else { continue }
                let aHref = gddLink.at_xpath("//td [@class='gdt2']")?.at_xpath("//a")?["href"]

                if gdt1Text.contains("Posted") {
                    infoPanel[0] = gdt2Text
                }
                if gdt1Text.contains("Parent") {
                    infoPanel[1] = aHref ?? "None"
                }
                if gdt1Text.contains("Visible") {
                    infoPanel[2] = gdt2Text
                }
                if gdt1Text.contains("Language") {
                    let words = gdt2Text.split(separator: " ")
                    if !words.isEmpty {
                        infoPanel[3] = words[0]
                            .trimmingCharacters(in: .whitespaces)
                    }
                }
                if gdt1Text.contains("File Size") {
                    infoPanel[4] = gdt2Text
                        .replacingOccurrences(of: " KB", with: "")
                        .replacingOccurrences(of: " MB", with: "")
                        .replacingOccurrences(of: " GB", with: "")

                    if gdt2Text.contains("KB") { infoPanel[5] = "KB" }
                    if gdt2Text.contains("MB") { infoPanel[5] = "MB" }
                    if gdt2Text.contains("GB") { infoPanel[5] = "GB" }
                }
                if gdt1Text.contains("Length") {
                    infoPanel[6] = gdt2Text.replacingOccurrences(of: " pages", with: "")
                }
                if gdt1Text.contains("Favorited") {
                    infoPanel[7] = gdt2Text
                        .replacingOccurrences(of: " times", with: "")
                        .replacingOccurrences(of: "Never", with: "0")
                        .replacingOccurrences(of: "Once", with: "1")
                }
            }

            guard infoPanel.filter({ !$0.isEmpty }).count == 8
            else { throw AppError.parseFailed }

            return infoPanel
        }

        func parseVisibility(value: String) throws -> GalleryVisibility {
            guard value != "Yes" else { return .yes }
            guard let rangeA = value.range(of: "("),
                  let rangeB = value.range(of: ")")
            else { throw AppError.parseFailed }

            let reason = String(value[rangeA.upperBound..<rangeB.lowerBound])
            return .no(reason: reason)
        }

        func parseUploader(node: XMLElement?) throws -> String {
            guard let gdnNode = node?.at_xpath("//div [@id='gdn']") else {
                throw AppError.parseFailed
            }

            if let aText = gdnNode.at_xpath("//a")?.text {
                return aText
            } else if let gdnText = gdnNode.text {
                return gdnText
            } else {
                throw AppError.parseFailed
            }
        }

        var tmpGalleryDetail: GalleryDetail?
        var tmpGalleryState: GalleryState?
        for link in doc.xpath("//div [@class='gm']") {
            guard tmpGalleryDetail == nil, tmpGalleryState == nil,
                  let gd3Node = link.at_xpath("//div [@id='gd3']"),
                  let gd4Node = link.at_xpath("//div [@id='gd4']"),
                  let gd5Node = link.at_xpath("//div [@id='gd5']"),
                  let gddNode = gd3Node.at_xpath("//div [@id='gdd']"),
                  let gdrNode = gd3Node.at_xpath("//div [@id='gdr']"),
                  let gdfNode = gd3Node.at_xpath("//div [@id='gdf']"),
                  let coverURL = try? parseCoverURL(node: link),
                  let tags = try? parseTags(node: gd4Node),
                  let previews = try? parsePreviews(doc: doc),
                  let arcAndTor = try? parseArcAndTor(node: gd5Node),
                  let infoPanel = try? parseInfoPanel(node: gddNode),
                  let visibility = try? parseVisibility(value: infoPanel[2]),
                  let sizeCount = Float(infoPanel[4]),
                  let pageCount = Int(infoPanel[6]),
                  let favoredCount = Int(infoPanel[7]),
                  let language = Language(rawValue: infoPanel[3]),
                  let engTitle = link.at_xpath("//h1 [@id='gn']")?.text,
                  let uploader = try? parseUploader(node: gd3Node),
                  let (imgRating, textRating, containsUserRating) = try? parseRating(node: gdrNode),
                  let ratingCount = Int(gdrNode.at_xpath("//span [@id='rating_count']")?.text ?? ""),
                  let category = Category(rawValue: gd3Node.at_xpath("//div [@id='gdc']")?.text ?? ""),
                  let postedDate = try? parseDate(time: infoPanel[0], format: Defaults.DateFormat.publish)
            else { continue }

            let isFavored = gdfNode
                .at_xpath("//a [@id='favoritelink']")?
                .text?.contains("Add to Favorites") == false
            let gjText = link.at_xpath("//h1 [@id='gj']")?.text
            let jpnTitle = gjText?.isEmpty != false ? nil : gjText

            tmpGalleryDetail = GalleryDetail(
                gid: gid,
                title: engTitle,
                jpnTitle: jpnTitle,
                isFavored: isFavored,
                visibility: visibility,
                rating: containsUserRating ?
                    textRating ?? 0.0 : imgRating,
                userRating: containsUserRating
                    ? imgRating : 0.0,
                ratingCount: ratingCount,
                category: category,
                language: language,
                uploader: uploader,
                postedDate: postedDate,
                coverURL: coverURL,
                archiveURL: arcAndTor.0,
                parentURL: infoPanel[1] == "None"
                    ? nil : infoPanel[1],
                favoredCount: favoredCount,
                pageCount: pageCount,
                sizeCount: sizeCount,
                sizeType: infoPanel[5],
                torrentCount: arcAndTor.1
            )
            tmpGalleryState = GalleryState(
                gid: gid, tags: tags,
                previews: previews,
                previewConfig: try? parsePreviewConfig(doc: doc),
                comments: parseComments(doc: doc)
            )
            break
        }

        guard let galleryDetail = tmpGalleryDetail,
              let galleryState = tmpGalleryState
        else {
            if let reason = doc.at_xpath("//div [@class='d']")?.at_xpath("//p")?.text {
                if let rangeA = reason.range(of: "copyright claim by "),
                   let rangeB = reason.range(of: ".Sorry about that.")
                {
                    let owner = String(reason[rangeA.upperBound..<rangeB.lowerBound])
                    throw AppError.copyrightClaim(owner: owner)
                } else {
                    throw AppError.expunged(reason: reason)
                }
            } else if let banInterval = parseBanInterval(doc: doc) {
                throw AppError.ipBanned(interval: banInterval)
            } else {
                throw AppError.parseFailed
            }
        }

        return (galleryDetail, galleryState)
    }

    // MARK: Preview
    static func parsePreviews(doc: HTMLDocument) throws -> [Int: String] {
        func parseNormalPreviews(node: XMLElement) -> [Int: String] {
            var previews = [Int: String]()

            for link in node.xpath("//div") where link.className == nil {
                guard let imgLink = link.at_xpath("//img"),
                      let index = Int(imgLink["alt"] ?? ""),
                      let linkStyle = link["style"],
                      let rangeA = linkStyle.range(of: "width:"),
                      let rangeB = linkStyle.range(of: "px; height:"),
                      let rangeC = linkStyle.range(of: "px; background"),
                      let rangeD = linkStyle.range(of: "url("),
                      let rangeE = linkStyle.range(of: ") -")
                else { continue }

                let remainingText = linkStyle[rangeE.upperBound...]
                guard let rangeF = remainingText.range(of: "px ")
                else { continue }

                let width = linkStyle[rangeA.upperBound..<rangeB.lowerBound]
                let height = linkStyle[rangeB.upperBound..<rangeC.lowerBound]
                let plainURL = linkStyle[rangeD.upperBound..<rangeE.lowerBound]
                let offset = remainingText[rangeE.upperBound..<rangeF.lowerBound]

                previews[index] = Defaults.URL.normalPreview(
                    plainURL: plainURL, width: width,
                    height: height, offset: offset
                )
            }

            return previews
        }
        func parseLargePreviews(node: XMLElement) -> [Int: String] {
            var previews = [Int: String]()

            for link in node.xpath("//img") {
                guard let index = Int(link["alt"] ?? ""),
                      let url = link["src"], !url.contains("blank.gif")
                else { continue }

                previews[index] = url
            }

            return previews
        }

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
              let previewMode = try? parsePreviewMode(doc: doc)
        else { throw AppError.parseFailed }

        return previewMode == "gdtl"
            ? parseLargePreviews(node: gdtNode)
            : parseNormalPreviews(node: gdtNode)
    }

    // MARK: Comment
    static func parseComments(doc: HTMLDocument) -> [GalleryComment] {
        var comments = [GalleryComment]()
        for link in doc.xpath("//div [@id='cdiv']") {
            for c1Link in link.xpath("//div [@class='c1']") {
                guard let c3Node = c1Link.at_xpath("//div [@class='c3']")?.text,
                      let c6Node = c1Link.at_xpath("//div [@class='c6']"),
                      let commentID = c6Node["id"]?
                        .replacingOccurrences(of: "comment_", with: ""),
                      let rangeA = c3Node.range(of: "Posted on "),
                      let rangeB = c3Node.range(of: " by:   ")
                else { continue }

                var score: String?
                if let c5Node = c1Link.at_xpath("//div [@class='c5 nosel']") {
                    score = c5Node.at_xpath("//span")?.text
                }
                let author = String(c3Node[rangeB.upperBound...])
                let commentTime = String(c3Node[rangeA.upperBound..<rangeB.lowerBound])

                var votedUp = false
                var votedDown = false
                var votable = false
                var editable = false
                if let c4Link = c1Link.at_xpath("//div [@class='c4 nosel']") {
                    for aLink in c4Link.xpath("//a") {
                        guard let aId = aLink["id"],
                              let aStyle = aLink["style"]
                        else {
                            if let aOnclick = aLink["onclick"],
                               aOnclick.contains("edit_comment") {
                                editable = true
                            }
                            continue
                        }

                        if aId.contains("vote_up") {
                            votable = true
                        }
                        if aId.contains("vote_up") && aStyle.contains("blue") {
                            votedUp = true
                        }
                        if aId.contains("vote_down") && aStyle.contains("blue") {
                            votedDown = true
                        }
                    }
                }

                let formatter = DateFormatter()
                formatter.dateFormat = Defaults.DateFormat.comment
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                guard let commentDate = formatter.date(from: commentTime) else { continue }

                comments.append(
                    GalleryComment(
                        votedUp: votedUp,
                        votedDown: votedDown,
                        votable: votable,
                        editable: editable,
                        score: score,
                        author: author,
                        contents: parseCommentContent(node: c6Node),
                        commentID: commentID,
                        commentDate: commentDate
                    )
                )
            }
        }
        return comments
    }

    // MARK: Content
    static func parseThumbnails(doc: HTMLDocument) throws -> [Int: String] {
        var thumbnails = [Int: String]()

        guard let gdtNode = doc.at_xpath("//div [@id='gdt']"),
              let previewMode = try? parsePreviewMode(doc: doc)
        else { throw AppError.parseFailed }

        for link in gdtNode.xpath("//div [@class='\(previewMode)']") {
            guard let aLink = link.at_xpath("//a"),
                  let thumbnail = aLink["href"],
                  let index = Int(aLink.at_xpath("//img")?["alt"] ?? "")
            else { continue }

            thumbnails[index] = thumbnail
        }

        return thumbnails
    }

    static func parseRenewedThumbnail(doc: HTMLDocument, stored: URL) throws -> URL {
        guard let text = doc.at_xpath("//div [@id='i6']")?.at_xpath("//a [@id='loadfail']")?["onclick"],
              let rangeA = text.range(of: "nl('"), let rangeB = text.range(of: "')")
        else { throw AppError.parseFailed }

        let reloadToken = String(text[rangeA.upperBound..<rangeB.lowerBound])
        let renewedString = stored.absoluteString + "?nl=" + reloadToken
        guard let renewedThumbnail = URL(string: renewedString)
        else { throw AppError.parseFailed }

        return renewedThumbnail
    }

    static func parseGalleryNormalContent(doc: HTMLDocument, index: Int) throws -> (Int, String, String?) {
        guard let i3Node = doc.at_xpath("//div [@id='i3']"),
              let imageURL = i3Node.at_css("img")?["src"]
        else { throw AppError.parseFailed }

        guard let i7Node = doc.at_xpath("//div [@id='i7']"),
              let originalImageURL = i7Node.at_xpath("//a")?["href"]
        else { return (index, imageURL, nil) }

        return (index, imageURL, originalImageURL)
    }

    static func parsePreviewMode(doc: HTMLDocument) throws -> String {
        guard let gdoNode = doc.at_xpath("//div [@id='gdo']"),
              let gdo4Node = gdoNode.at_xpath("//div [@id='gdo4']")
        else { return "gdtm" }

        for link in gdo4Node.xpath("//div") where link.text == "Large" {
            return link["class"] == "ths nosel" ? "gdtl" : "gdtm"
        }
        return "gdtm"
    }

    static func parseMPVKeys(doc: HTMLDocument) throws -> (String, [Int: String]) {
        var tmpMPVKey: String?
        var imgKeys = [Int: String]()

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let text = link.text,
                  let rangeA = text.range(of: "mpvkey = \""),
                  let rangeB = text.range(of: "\";\nvar imagelist = "),
                  let rangeC = text.range(of: "\"}]")
            else { continue }

            tmpMPVKey = String(text[rangeA.upperBound..<rangeB.lowerBound])

            guard let data = String(text[rangeB.upperBound..<rangeC.upperBound])
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "\"", with: "\"")
                .replacingOccurrences(of: "\n", with: "")
                .data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(
                    with: data) as? [[String: String]]
            else { throw AppError.parseFailed }

            array.enumerated().forEach { (index, dict) in
                if let imgKey = dict["k"] {
                    imgKeys[index + 1] = imgKey
                }
            }
        }

        guard let mpvKey = tmpMPVKey, !imgKeys.isEmpty
        else { throw AppError.parseFailed }

        return (mpvKey, imgKeys)
    }

    // MARK: User
    static func parseUserInfo(doc: HTMLDocument) throws -> User {
        var displayName: String?
        var avatarURL: String?

        for ipbLink in doc.xpath("//table [@class='ipbtable']") {
            guard let profileName = ipbLink.at_xpath("//div [@id='profilename']")?.text
            else { continue }

            displayName = profileName

            for imgLink in ipbLink.xpath("//img") {
                guard let imgURL = imgLink["src"],
                      imgURL.contains("forums.e-hentai.org/uploads")
                else { continue }

                avatarURL = imgURL
            }
        }
        if displayName != nil {
            return User(displayName: displayName, avatarURL: avatarURL)
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: Archive
    static func parseGalleryArchive(doc: HTMLDocument) throws -> GalleryArchive {
        guard let node = doc.at_xpath("//table")
        else { throw AppError.parseFailed }

        var hathArchives = [GalleryArchive.HathArchive]()
        for link in node.xpath("//td") {
            var tmpResolution: ArchiveRes?
            var tmpFileSize: String?
            var tmpGPPrice: String?

            for pLink in link.xpath("//p") {
                if let pText = pLink.text {
                    if let res = ArchiveRes(rawValue: pText) {
                        tmpResolution = res
                    }
                    if pText.contains("N/A") {
                        tmpFileSize = "N/A"
                        tmpGPPrice = "N/A"

                        if tmpResolution != nil {
                            break
                        }
                    } else {
                        if pText.contains("KB")
                            || pText.contains("MB")
                            || pText.contains("GB")
                        {
                            tmpFileSize = pText
                        } else {
                            tmpGPPrice = pText
                        }
                    }
                }
            }

            guard let resolution = tmpResolution,
                  let fileSize = tmpFileSize,
                  let gpPrice = tmpGPPrice
            else { continue }

            hathArchives.append(
                GalleryArchive.HathArchive(
                    resolution: resolution,
                    fileSize: fileSize,
                    gpPrice: gpPrice
                )
            )
        }

        return GalleryArchive(hathArchives: hathArchives)
    }

    // MARK: Torrent
    static func parseGalleryTorrents(doc: HTMLDocument) -> [GalleryTorrent] {
        var torrents = [GalleryTorrent]()

        for link in doc.xpath("//form") {
            var tmpPostedTime: String?
            var tmpFileSize: String?
            var tmpSeedCount: Int?
            var tmpPeerCount: Int?
            var tmpDownloadCount: Int?
            var tmpUploader: String?
            var tmpFileName: String?
            var tmpHash: String?
            var tmpTorrentURL: String?

            for trLink in link.xpath("//tr") {
                for tdLink in trLink.xpath("//td") {
                    if let tdText = tdLink.text {
                        if tdText.contains("Posted: ") {
                            tmpPostedTime = tdText.replacingOccurrences(of: "Posted: ", with: "")
                        }
                        if tdText.contains("Size: ") {
                            tmpFileSize = tdText.replacingOccurrences(of: "Size: ", with: "")
                        }
                        if tdText.contains("Seeds: ") {
                            tmpSeedCount = Int(tdText.replacingOccurrences(of: "Seeds: ", with: ""))
                        }
                        if tdText.contains("Peers: ") {
                            tmpPeerCount = Int(tdText.replacingOccurrences(of: "Peers: ", with: ""))
                        }
                        if tdText.contains("Downloads: ") {
                            tmpDownloadCount = Int(tdText.replacingOccurrences(of: "Downloads: ", with: ""))
                        }
                        if tdText.contains("Uploader: ") {
                            tmpUploader = tdText.replacingOccurrences(of: "Uploader: ", with: "")
                        }
                    }
                    if let aLink = tdLink.at_xpath("//a"),
                       let aHref = aLink["href"],
                       let aText = aLink.text,
                       let aURL = URL(string: aHref),
                       let range = aURL.lastPathComponent.range(of: ".torrent")
                    {
                        tmpHash = String(aURL.lastPathComponent[..<range.lowerBound])
                        tmpTorrentURL = aHref
                        tmpFileName = aText
                    }
                }
            }

            guard let postedTime = tmpPostedTime,
                  let postedDate = try? parseDate(
                    time: postedTime,
                    format: Defaults.DateFormat.torrent
                  ),
                  let fileSize = tmpFileSize,
                  let seedCount = tmpSeedCount,
                  let peerCount = tmpPeerCount,
                  let downloadCount = tmpDownloadCount,
                  let uploader = tmpUploader,
                  let fileName = tmpFileName,
                  let hash = tmpHash,
                  let torrentURL = tmpTorrentURL
            else { continue }

            torrents.append(
                GalleryTorrent(
                    postedDate: postedDate,
                    fileSize: fileSize,
                    seedCount: seedCount,
                    peerCount: peerCount,
                    downloadCount: downloadCount,
                    uploader: uploader,
                    fileName: fileName,
                    hash: hash,
                    torrentURL: torrentURL
                )
            )
        }

        return torrents
    }
}

extension Parser {
    // MARK: Greeting
    static func parseGreeting(doc: HTMLDocument) throws -> Greeting {
        func trim(string: String) -> String? {
            if string.contains("EXP") {
                return "EXP"
            } else if string.contains("Credits") {
                return "Credits"
            } else if string.contains("GP") {
                return "GP"
            } else if string.contains("Hath") {
                return "Hath"
            } else {
                return nil
            }
        }

        func trim(int: String) -> Int? {
            Int(int.replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: " ", with: ""))
        }

        guard let node = doc.at_xpath("//div [@id='eventpane']")
        else { throw AppError.parseFailed }

        var greeting = Greeting()
        for link in node.xpath("//p") {
            guard var text = link.text,
                  text.contains("You gain") == true
            else { continue }

            var gainedValues = [String]()
            for strongLink in link.xpath("//strong") {
                if let strongText = strongLink.text {
                    gainedValues.append(strongText)
                }
            }

            var gainedTypes = [String]()
            for value in gainedValues {
                guard let range = text.range(of: value) else { break }
                let removeText = String(text[..<range.upperBound])

                if value != gainedValues.first {
                    if let text = trim(string: removeText) {
                        gainedTypes.append(text)
                    }
                }

                text = text.replacingOccurrences(of: removeText, with: "")

                if value == gainedValues.last {
                    if let text = trim(string: text) {
                        gainedTypes.append(text)
                    }
                }
            }

            let gainedIntValues = gainedValues.compactMap { trim(int: $0) }
            guard gainedIntValues.count == gainedTypes.count
            else { throw AppError.parseFailed }

            for (index, type) in gainedTypes.enumerated() {
                let value = gainedIntValues[index]
                switch type {
                case "EXP":
                    greeting.gainedEXP = value
                case "Credits":
                    greeting.gainedCredits = value
                case "GP":
                    greeting.gainedGP = value
                case "Hath":
                    greeting.gainedHath = value
                default:
                    break
                }
            }
            break
        }

        greeting.updateTime = Date()
        return greeting
    }

    // MARK: EhSetting
    static func parseEhSetting(doc: HTMLDocument) throws -> EhSetting {
        func parseInt(node: XMLElement, name: String) -> Int? {
            var value: Int?
            for link in node.xpath("//input [@name='\(name)']")
                where link["checked"] == "checked" {
                value = Int(link["value"] ?? "")
            }
            return value
        }
        func parseEnum<T: RawRepresentable>(node: XMLElement, name: String) -> T?
            where T.RawValue == Int
        {
            guard let rawValue = parseInt(
                node: node, name: name
            ) else { return nil }
            return T(rawValue: rawValue)
        }
        func parseString(node: XMLElement, name: String) -> String? {
            node.at_xpath("//input [@name='\(name)']")?["value"]
        }
        func parseTextEditorString(node: XMLElement, name: String) -> String? {
            node.at_xpath("//textarea [@name='\(name)']")?.text
        }
        func parseBool(node: XMLElement, name: String) -> Bool? {
            switch parseString(node: node, name: name) {
            case "0": return false
            case "1": return true
            default: return nil
            }
        }
        func parseCheckBoxBool(node: XMLElement, name: String) -> Bool? {
            node.at_xpath("//input [@name='\(name)']")?["checked"] == "checked"
        }
        func parseCapability<T: RawRepresentable>(node: XMLElement, name: String) -> T?
            where T.RawValue == Int
        {
            var maxValue: Int?
            for link in node.xpath("//input [@name='\(name)']")
                where link["disabled"] != "disabled"
            {
                let value = Int(link["value"] ?? "") ?? 0
                if maxValue == nil {
                    maxValue = value
                } else if maxValue ?? 0 < value {
                    maxValue = value
                }
            }
            return T(rawValue: maxValue ?? 0)
        }
        func parseSelections(node: XMLElement, name: String) -> [(String, String, Bool)] {
            guard let select = node.at_xpath("//select [@name='\(name)']")
            else { return [] }

            var selections = [(String, String, Bool)]()
            for link in select.xpath("//option") {
                guard let name = link.text,
                      let value = link["value"]
                else { continue }

                selections.append((name, value, link["selected"] == "selected"))
            }

            return selections
        }

        var tmpForm: XMLElement?
        for link in doc.xpath("//form [@method='post']")
            where link["id"] == nil {
            tmpForm = link
        }
        guard let profileOuter = doc.at_xpath("//div [@id='profile_outer']"),
              let form = tmpForm else { throw AppError.parseFailed }

        // swiftlint:disable line_length
        var tmpEhProfiles = [EhProfile](); var tmpCapableLoadThroughHathSetting: EhSettingLoadThroughHathSetting?; var tmpCapableImageResolution: EhSettingImageResolution?; var tmpCapableSearchResultCount: EhSettingSearchResultCount?; var tmpCapableThumbnailConfigSize: EhSettingThumbnailSize?; var tmpCapableThumbnailConfigRows: EhSettingThumbnailRows?; var tmpLoadThroughHathSetting: EhSettingLoadThroughHathSetting?; var tmpBrowsingCountry: EhSettingBrowsingCountry?; var tmpImageResolution: EhSettingImageResolution?; var tmpImageSizeWidth: Float?; var tmpImageSizeHeight: Float?; var tmpGalleryName: EhSettingGalleryName?; var tmpLiteralBrowsingCountry: String?; var tmpArchiverBehavior: EhSettingArchiverBehavior?; var tmpDisplayMode: EhSettingDisplayMode?; var tmpDisabledCategories = [Bool](); var tmpFavoritesNames = [String](); var tmpFavoritesSortOrder: EhSettingFavoritesSortOrder?; var tmpRatingsColor: String?; var tmpExcludedNamespaces = [Bool](); var tmpTagFilteringThreshold: Float?; var tmpTagWatchingThreshold: Float?; var tmpExcludedLanguages = [Bool](); var tmpExcludedUploaders: String?; var tmpSearchResultCount: EhSettingSearchResultCount?; var tmpThumbnailLoadTiming: EhSettingThumbnailLoadTiming?; var tmpThumbnailConfigSize: EhSettingThumbnailSize?; var tmpThumbnailConfigRows: EhSettingThumbnailRows?; var tmpThumbnailScaleFactor: Float?; var tmpViewportVirtualWidth: Float?; var tmpCommentsSortOrder: EhSettingCommentsSortOrder?; var tmpCommentVotesShowTiming: EhSettingCommentVotesShowTiming?; var tmpTagsSortOrder: EhSettingTagsSortOrder?; var tmpGalleryShowPageNumbers: Bool?; var tmpHathLocalNetworkHost: String?; var tmpUseOriginalImages: Bool?; var tmpUseMultiplePageViewer: Bool?; var tmpMultiplePageViewerStyle: EhSettingMultiplePageViewerStyle?; var tmpMultiplePageViewerShowThumbnailPane: Bool?
        // swiftlint:enable line_length

        tmpEhProfiles = parseSelections(node: profileOuter, name: "profile_set")
            .compactMap { (name, value, isSelected) in
                guard let value = Int(value)
                else { return nil }

                return EhProfile(
                    value: value, name: name,
                    isSelected: isSelected
                )
            }

        for optouter in form.xpath("//div [@class='optouter']") {
            if optouter.at_xpath("//input [@name='uh']") != nil {
                tmpLoadThroughHathSetting = parseEnum(node: optouter, name: "uh")
                tmpCapableLoadThroughHathSetting = parseCapability(node: optouter, name: "uh")
            }
            if optouter.at_xpath("//select [@name='co']") != nil {
                var value = parseSelections(node: optouter, name: "co").filter(\.2).first?.1

                if value == "" { value = "-" }
                tmpBrowsingCountry = EhSettingBrowsingCountry(rawValue: value ?? "")

                if let pText = optouter.at_xpath("//p")?.text,
                   let rangeA = pText.range(of: "You appear to be browsing the site from "),
                   let rangeB = pText.range(of: " or use a VPN or proxy in this country")
                {
                    tmpLiteralBrowsingCountry = String(pText[rangeA.upperBound..<rangeB.lowerBound])
                }
            }
            if optouter.at_xpath("//input [@name='xr']") != nil {
                tmpImageResolution = parseEnum(node: optouter, name: "xr")
                tmpCapableImageResolution = parseCapability(node: optouter, name: "xr")
            }
            if optouter.at_xpath("//input [@name='rx']") != nil {
                tmpImageSizeWidth = Float(parseString(node: optouter, name: "rx") ?? "0")
                if tmpImageSizeWidth == nil { tmpImageSizeWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='ry']") != nil {
                tmpImageSizeHeight = Float(parseString(node: optouter, name: "ry") ?? "0")
                if tmpImageSizeHeight == nil { tmpImageSizeHeight = 0 }
            }
            if optouter.at_xpath("//input [@name='tl']") != nil {
                tmpGalleryName = parseEnum(node: optouter, name: "tl")
            }
            if optouter.at_xpath("//input [@name='ar']") != nil {
                tmpArchiverBehavior = parseEnum(node: optouter, name: "ar")
            }
            if optouter.at_xpath("//input [@name='dm']") != nil {
                tmpDisplayMode = parseEnum(node: optouter, name: "dm")
            }
            if optouter.at_xpath("//div [@id='catsel']") != nil {
                tmpDisabledCategories = Array(0...9)
                    .map { "ct_\(EhSetting.categoryNames[$0])" }
                    .compactMap { parseBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//div [@id='favsel']") != nil {
                tmpFavoritesNames = Array(0...9).map { "favorite_\($0)" }
                    .compactMap { parseString(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//input [@name='fs']") != nil {
                tmpFavoritesSortOrder = parseEnum(node: optouter, name: "fs")
            }
            if optouter.at_xpath("//input [@name='ru']") != nil {
                tmpRatingsColor = parseString(node: optouter, name: "ru") ?? ""
            }
            if optouter.at_xpath("//div [@id='nssel']") != nil {
                tmpExcludedNamespaces = Array(1...11).map { "xn_\($0)" }
                    .compactMap { parseCheckBoxBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//input [@name='ft']") != nil {
                tmpTagFilteringThreshold = Float(parseString(node: optouter, name: "ft") ?? "0")
                if tmpTagFilteringThreshold == nil { tmpTagFilteringThreshold = 0 }
            }
            if optouter.at_xpath("//input [@name='wt']") != nil {
                tmpTagWatchingThreshold = Float(parseString(node: optouter, name: "wt") ?? "0")
                if tmpTagWatchingThreshold == nil { tmpTagWatchingThreshold = 0 }
            }
            if optouter.at_xpath("//div [@id='xlasel']") != nil {
                tmpExcludedLanguages = Array(0...49)
                    .map { "xl_\(EhSetting.languageValues[$0])" }
                    .compactMap { parseCheckBoxBool(node: optouter, name: $0) }
            }
            if optouter.at_xpath("//textarea [@name='xu']") != nil {
                tmpExcludedUploaders = parseTextEditorString(node: optouter, name: "xu") ?? ""
            }
            if optouter.at_xpath("//input [@name='rc']") != nil {
                tmpSearchResultCount = parseEnum(node: optouter, name: "rc")
                tmpCapableSearchResultCount = parseCapability(node: optouter, name: "rc")
            }
            if optouter.at_xpath("//input [@name='lt']") != nil {
                tmpThumbnailLoadTiming = parseEnum(node: optouter, name: "lt")
            }
            if optouter.at_xpath("//input [@name='ts']") != nil {
                tmpThumbnailConfigSize = parseEnum(node: optouter, name: "ts")
                tmpCapableThumbnailConfigSize = parseCapability(node: optouter, name: "ts")
            }
            if optouter.at_xpath("//input [@name='tr']") != nil {
                tmpThumbnailConfigRows = parseEnum(node: optouter, name: "tr")
                tmpCapableThumbnailConfigRows = parseCapability(node: optouter, name: "tr")
            }
            if optouter.at_xpath("//input [@name='tp']") != nil {
                tmpThumbnailScaleFactor = Float(parseString(node: optouter, name: "tp") ?? "100")
                if tmpThumbnailScaleFactor == nil { tmpThumbnailScaleFactor = 100 }
            }
            if optouter.at_xpath("//input [@name='vp']") != nil {
                tmpViewportVirtualWidth = Float(parseString(node: optouter, name: "vp") ?? "0")
                if tmpViewportVirtualWidth == nil { tmpViewportVirtualWidth = 0 }
            }
            if optouter.at_xpath("//input [@name='cs']") != nil {
                tmpCommentsSortOrder = parseEnum(node: optouter, name: "cs")
            }
            if optouter.at_xpath("//input [@name='sc']") != nil {
                tmpCommentVotesShowTiming = parseEnum(node: optouter, name: "sc")
            }
            if optouter.at_xpath("//input [@name='tb']") != nil {
                tmpTagsSortOrder = parseEnum(node: optouter, name: "tb")
            }
            if optouter.at_xpath("//input [@name='pn']") != nil {
                tmpGalleryShowPageNumbers = parseInt(node: optouter, name: "pn") == 1
            }
            if optouter.at_xpath("//input [@name='hh']") != nil {
                tmpHathLocalNetworkHost = parseString(node: optouter, name: "hh")
            }
            if optouter.at_xpath("//input [@name='oi']") != nil {
                tmpUseOriginalImages = parseInt(node: optouter, name: "oi") == 1
            }
            if optouter.at_xpath("//input [@name='qb']") != nil {
                tmpUseMultiplePageViewer = parseInt(node: optouter, name: "qb") == 1
            }
            if optouter.at_xpath("//input [@name='ms']") != nil {
                tmpMultiplePageViewerStyle = parseEnum(node: optouter, name: "ms")
            }
            if optouter.at_xpath("//input [@name='mt']") != nil {
                tmpMultiplePageViewerShowThumbnailPane = parseInt(node: optouter, name: "mt") == 0
            }
        }

        // swiftlint:disable line_length
        guard !tmpEhProfiles.filter(\.isSelected).isEmpty, let capableLoadThroughHathSetting = tmpCapableLoadThroughHathSetting, let capableImageResolution = tmpCapableImageResolution, let capableSearchResultCount = tmpCapableSearchResultCount, let capableThumbnailConfigSize = tmpCapableThumbnailConfigSize, let capableThumbnailConfigRows = tmpCapableThumbnailConfigRows, let loadThroughHathSetting = tmpLoadThroughHathSetting, let browsingCountry = tmpBrowsingCountry, let literalBrowsingCountry = tmpLiteralBrowsingCountry, let imageResolution = tmpImageResolution, let imageSizeWidth = tmpImageSizeWidth, let imageSizeHeight = tmpImageSizeHeight, let galleryName = tmpGalleryName, let archiverBehavior = tmpArchiverBehavior, let displayMode = tmpDisplayMode, tmpDisabledCategories.count == 10, tmpFavoritesNames.count == 10, let favoritesSortOrder = tmpFavoritesSortOrder, let ratingsColor = tmpRatingsColor, tmpExcludedNamespaces.count == 11, let tagFilteringThreshold = tmpTagFilteringThreshold, let tagWatchingThreshold = tmpTagWatchingThreshold, tmpExcludedLanguages.count == 50, let excludedUploaders = tmpExcludedUploaders, let searchResultCount = tmpSearchResultCount, let thumbnailLoadTiming = tmpThumbnailLoadTiming, let thumbnailConfigSize = tmpThumbnailConfigSize, let thumbnailConfigRows = tmpThumbnailConfigRows, let thumbnailScaleFactor = tmpThumbnailScaleFactor, let viewportVirtualWidth = tmpViewportVirtualWidth, let commentsSortOrder = tmpCommentsSortOrder, let commentVotesShowTiming = tmpCommentVotesShowTiming, let tagsSortOrder = tmpTagsSortOrder, let galleryShowPageNumbers = tmpGalleryShowPageNumbers, let hathLocalNetworkHost = tmpHathLocalNetworkHost
        else { throw AppError.parseFailed }

        return EhSetting(ehProfiles: tmpEhProfiles.sorted(), capableLoadThroughHathSetting: capableLoadThroughHathSetting, capableImageResolution: capableImageResolution, capableSearchResultCount: capableSearchResultCount, capableThumbnailConfigSize: capableThumbnailConfigSize, capableThumbnailConfigRows: capableThumbnailConfigRows, loadThroughHathSetting: loadThroughHathSetting, browsingCountry: browsingCountry, literalBrowsingCountry: literalBrowsingCountry, imageResolution: imageResolution, imageSizeWidth: imageSizeWidth, imageSizeHeight: imageSizeHeight, galleryName: galleryName, archiverBehavior: archiverBehavior, displayMode: displayMode, disabledCategories: tmpDisabledCategories, favoriteNames: tmpFavoritesNames, favoritesSortOrder: favoritesSortOrder, ratingsColor: ratingsColor, excludedNamespaces: tmpExcludedNamespaces, tagFilteringThreshold: tagFilteringThreshold, tagWatchingThreshold: tagWatchingThreshold, excludedLanguages: tmpExcludedLanguages, excludedUploaders: excludedUploaders, searchResultCount: searchResultCount, thumbnailLoadTiming: thumbnailLoadTiming, thumbnailConfigSize: thumbnailConfigSize, thumbnailConfigRows: thumbnailConfigRows, thumbnailScaleFactor: thumbnailScaleFactor, viewportVirtualWidth: viewportVirtualWidth, commentsSortOrder: commentsSortOrder, commentVotesShowTiming: commentVotesShowTiming, tagsSortOrder: tagsSortOrder, galleryShowPageNumbers: galleryShowPageNumbers, hathLocalNetworkHost: hathLocalNetworkHost, useOriginalImages: tmpUseOriginalImages, useMultiplePageViewer: tmpUseMultiplePageViewer, multiplePageViewerStyle: tmpMultiplePageViewerStyle, multiplePageViewerShowThumbnailPane: tmpMultiplePageViewerShowThumbnailPane
        )
        // swiftlint:enable line_length
    }

    // MARK: APIKey
    static func parseAPIKey(doc: HTMLDocument) throws -> APIKey {
        var tmpKey: APIKey?

        for link in doc.xpath("//script [@type='text/javascript']") {
            guard let script = link.text, script.contains("apikey"),
                  let rangeA = script.range(of: ";\nvar apikey = \""),
                  let rangeB = script.range(of: "\";\nvar average_rating")
            else { continue }

            tmpKey = String(script[rangeA.upperBound..<rangeB.lowerBound])
        }

        guard let apikey = tmpKey
        else { throw AppError.parseFailed }

        return apikey
    }
    // MARK: Date
    static func parseDate(time: String, format: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: time)
        else { throw AppError.parseFailed }

        return date
    }

    // MARK: Rating
    /// Returns ratings parsed from stars image / text and if the return contains a userRating .
    static func parseRating(node: XMLElement) throws -> (Float, Float?, Bool) {
        func parseTextRating(node: XMLElement) throws -> Float {
            guard let ratingString = node
              .at_xpath("//td [@id='rating_label']")?.text?
              .replacingOccurrences(of: "Average: ", with: "")
              .replacingOccurrences(of: "Not Yet Rated", with: "0"),
                  let rating = Float(ratingString)
            else { throw AppError.parseFailed }

            return rating
        }

        var tmpRatingString: String?
        var containsUserRating = false

        for link in node.xpath("//div") where
            link.className?.contains("ir") == true
            && link["style"]?.isEmpty == false
        {
            if tmpRatingString != nil { break }
            tmpRatingString = link["style"]
            containsUserRating = link.className != "ir"
        }

        guard let ratingString = tmpRatingString
        else { throw AppError.parseFailed }

        var tmpRating: Float?
        if ratingString.contains("0px") { tmpRating = 5.0 }
        if ratingString.contains("-16px") { tmpRating = 4.0 }
        if ratingString.contains("-32px") { tmpRating = 3.0 }
        if ratingString.contains("-48px") { tmpRating = 2.0 }
        if ratingString.contains("-64px") { tmpRating = 1.0 }
        if ratingString.contains("-80px") { tmpRating = 0.0 }

        guard var rating = tmpRating
        else { throw AppError.parseFailed }

        if ratingString.contains("-21px") { rating -= 0.5 }
        return (rating, try? parseTextRating(node: node), containsUserRating)
    }

    // MARK: PageNumber
    static func parsePageNum(doc: HTMLDocument) -> PageNumber {
        var current = 0
        var maximum = 0

        guard let link = doc.at_xpath("//table [@class='ptt']"),
              let currentStr = link.at_xpath("//td [@class='ptds']")?.text
        else { return PageNumber() }

        if let range = currentStr.range(of: "-") {
            current = (Int(currentStr[range.upperBound...]) ?? 1) - 1
        } else {
            current = (Int(currentStr) ?? 1) - 1
        }
        for aLink in link.xpath("//a") {
            if let num = Int(aLink.text ?? "") {
                maximum = num - 1
            }
        }
        return PageNumber(current: current, maximum: maximum)
    }

    // MARK: SortOrder
    static func parseFavoritesSortOrder(doc: HTMLDocument) -> FavoritesSortOrder? {
        guard let idoNode = doc.at_xpath("//div [@class='ido']") else { return nil }
        for link in idoNode.xpath("//div") where link.className == nil {
            guard let aText = link.at_xpath("//div")?.at_xpath("//a")?.text else { continue }
            if aText == "Use Posted" {
                return .favoritedTime
            } else if aText == "Use Favorited" {
                return .lastUpdateTime
            }
        }
        return nil
    }

    // MARK: Balance
    static func parseCurrentFunds(doc: HTMLDocument) throws -> (String, String)? {
        var tmpGP: String?
        var tmpCredits: String?

        for element in doc.xpath("//p") {
            if let text = element.text,
               let rangeA = text.range(of: "GP"),
               let rangeB = text.range(of: "[?]"),
               let rangeC = text.range(of: "Credits")
            {
                tmpGP = String(text[..<rangeA.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: "")
                tmpCredits = String(text[rangeB.upperBound..<rangeC.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ",", with: "")
            }
        }

        guard let galleryPoints = tmpGP, let credits = tmpCredits
        else { throw AppError.parseFailed }

        return (galleryPoints, credits)
    }

    // MARK: DownloadCmdResp
    static func parseDownloadCommandResponse(doc: HTMLDocument) throws -> String {
        guard let dbNode = doc.at_xpath("//div [@id='db']")
        else { throw AppError.parseFailed }

        var response = [String]()
        for pLink in dbNode.xpath("//p") {
            if let pText = pLink.text {
                response.append(pText)
            }
        }

        var respString = response.joined(separator: " ")

        if let rangeA =
            respString.range(of: "A ") ?? respString.range(of: "An "),
           let rangeB = respString.range(of: "resolution"),
           let rangeC = respString.range(of: "client"),
           let rangeD = respString.range(of: "Downloads")
        {
            let resp = String(respString[rangeA.upperBound..<rangeB.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .firstLetterCapitalized

            if ArchiveRes(rawValue: resp) != nil {
                let clientName = String(respString[rangeC.upperBound..<rangeD.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                respString = resp.localized + " -> " + clientName
            }
        }

        return respString
    }

    // MARK: ArchiveURL
    static func parseArchiveURL(node: XMLElement) throws -> String {
        var archiveURL: String?
        if let aLink = node.at_xpath("//a"),
           aLink.text?.contains("Archive Download") == true,
           let onClick = aLink["onclick"],
           let rangeA = onClick.range(of: "popUp('"),
           let rangeB = onClick.range(of: "',")
        {
            archiveURL = String(onClick[rangeA.upperBound..<rangeB.lowerBound])
        }

        if let url = archiveURL {
            return url
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: FavoriteNames
    static func parseFavoriteNames(doc: HTMLDocument) throws -> [Int: String] {
        var favoriteNames = [Int: String]()

        for link in doc.xpath("//div [@id='favsel']") {
            for inputLink in link.xpath("//input") {
                guard let name = inputLink["name"],
                      let value = inputLink["value"],
                      let type = FavoritesType(rawValue: name)
                else { continue }

                favoriteNames[type.index] = value
            }
        }

        if !favoriteNames.isEmpty {
            return favoriteNames
        } else {
            throw AppError.parseFailed
        }
    }

    // MARK: Profile
    static func parseProfileIndex(doc: HTMLDocument) throws -> (Int?, Bool) {
        var profileNotFound = true
        var profileValue: Int?

        let selector = doc.at_xpath("//select [@name='profile_set']")
        let options = selector?.xpath("//option")

        guard let options = options, options.count >= 1
        else { throw AppError.parseFailed }

        for link in options where AppUtil.verifyEhPandaProfileName(with: link.text) {
            profileNotFound = false
            profileValue = Int(link["value"] ?? "")
        }

        return (profileValue, profileNotFound)
    }

    // MARK: CommentContent
    static func parseCommentContent(node: XMLElement) -> [CommentContent] {
        var contents = [CommentContent]()

        for div in node.xpath("//div") {
            node.removeChild(div)
        }
        for span in node.xpath("span") {
            node.removeChild(span)
        }

        guard var rawContent = node.innerHTML?
                .replacingOccurrences(of: "<br>", with: "\n")
                .replacingOccurrences(of: "</span>", with: "")
        else { return [] }

        while (node.xpath("//a").count
                + node.xpath("//img").count) > 0
        {
            var tmpLink: XMLElement?

            let links = [
                node.at_xpath("//a"),
                node.at_xpath("//img")
            ]
            .compactMap({ $0 })

            links.forEach { newLink in
                if tmpLink == nil {
                    tmpLink = newLink
                } else {
                    if let tmpHTML = tmpLink?.toHTML,
                       let newHTML = newLink.toHTML,
                       let tmpBound = rawContent.range(of: tmpHTML)?.lowerBound,
                       let newBound = rawContent.range(of: newHTML)?.lowerBound,
                       newBound < tmpBound
                    {
                        tmpLink = newLink
                    }
                }
            }

            guard let link = tmpLink,
                  let html = link.toHTML?
                    .replacingOccurrences(of: "<br>", with: "\n")
                    .replacingOccurrences(of: "</span>", with: ""),
                  let range = rawContent.range(of: html)
            else { continue }

            let text = String(rawContent[..<range.lowerBound])
            if !text.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                contents.append(
                    CommentContent(
                        type: .plainText,
                        text: text
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                    )
                )
            }

            if let href = link["href"] {
                if let imgSrc = link.at_xpath("//img")?["src"] {
                    if let content = contents.last,
                       content.type == .linkedImg
                    {
                        contents = contents.dropLast()
                        contents.append(
                            CommentContent(
                                type: .doubleLinkedImg,
                                link: content.link,
                                imgURL: content.imgURL,
                                secondLink: href,
                                secondImgURL: imgSrc
                            )
                        )
                    } else {
                        contents.append(
                            CommentContent(
                                type: .linkedImg,
                                link: href,
                                imgURL: imgSrc
                            )
                        )
                    }
                } else if let text = link.text {
                    if !text
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        )
                        .isEmpty
                    {
                        contents.append(
                            CommentContent(
                                type: .linkedText,
                                text: text
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    ),
                                link: href
                            )
                        )
                    }
                } else {
                    contents.append(
                        CommentContent(
                            type: .singleLink,
                            link: href
                        )
                    )
                }
            } else if let src = link["src"] {
                if let content = contents.last,
                   content.type == .singleImg
                {
                    contents = contents.dropLast()
                    contents.append(
                        CommentContent(
                            type: .doubleImg,
                            imgURL: content.imgURL,
                            secondImgURL: src
                        )
                    )
                } else {
                    contents.append(
                        CommentContent(
                            type: .singleImg,
                            imgURL: src
                        )
                    )
                }

            }

            rawContent.removeSubrange(..<range.upperBound)
            node.removeChild(link)

            if (node.xpath("//a").count
                    + node.xpath("//img").count) <= 0
            {
                if !rawContent
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty
                {
                    contents.append(
                        CommentContent(
                            type: .plainText,
                            text: rawContent
                                .trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )
                        )
                    )
                }
            }
        }

        if !rawContent.isEmpty && contents.isEmpty {
            if !rawContent
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .isEmpty
            {
                contents.append(
                    CommentContent(
                        type: .plainText,
                        text: rawContent
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                    )
                )
            }
        }

        return contents
    }

    // MARK: parsePreviewConfigs
    static func parsePreviewConfigs(string: String) -> (String, CGSize, CGSize)? {
        guard let rangeA = string.range(of: Defaults.PreviewIdentifier.width),
              let rangeB = string.range(of: Defaults.PreviewIdentifier.height),
              let rangeC = string.range(of: Defaults.PreviewIdentifier.offset)
        else { return nil }

        let plainURL = String(string[..<rangeA.lowerBound])
        guard let width = Int(string[rangeA.upperBound..<rangeB.lowerBound]),
              let height = Int(string[rangeB.upperBound..<rangeC.lowerBound]),
              let offsetX = Int(string[rangeC.upperBound...])
        else { return nil }

        let size = CGSize(width: width, height: height)
        return (plainURL, size, CGSize(width: offsetX, height: 0))
    }

    // MARK: parseWrappedHex
    static func parseWrappedHex(string: String) -> (String, String?) {
        let hexStart = Defaults.ParsingMark.hexStart
        let hexEnd = Defaults.ParsingMark.hexEnd
        guard let rangeA = string.range(of: hexStart),
              let rangeB = string.range(of: hexEnd)
        else { return (string, nil) }

        let wrappedHex = String(string[rangeA.upperBound..<rangeB.lowerBound])
        let rippedText = string.replacingOccurrences(of: hexStart + wrappedHex + hexEnd, with: "")

        return (rippedText, wrappedHex)
    }

    // MARK: parseBanInterval
    static func parseBanInterval(doc: HTMLDocument) -> BanInterval? {
        guard let text = doc.body?.text, let range = text.range(of: "The ban expires in ")
        else { return nil }

        let expireDescription = String(text[range.upperBound...])

        if let daysRange = expireDescription.range(of: "days"),
           let days = Int(expireDescription[..<daysRange.lowerBound]
                            .trimmingCharacters(in: .whitespaces))
        {
            if let andRange = expireDescription.range(of: "and"),
               let hoursRange = expireDescription.range(of: "hours"),
               let hours = Int(expireDescription[andRange.upperBound..<hoursRange.lowerBound]
                                 .trimmingCharacters(in: .whitespaces))
            {
                return .days(days, hours: hours)
            } else {
                return .days(days, hours: nil)
            }
        } else if let hoursRange = expireDescription.range(of: "hours"),
                  let hours = Int(expireDescription[..<hoursRange.lowerBound]
                                    .trimmingCharacters(in: .whitespaces))
        {
            if let andRange = expireDescription.range(of: "and"),
               let minutesRange = expireDescription.range(of: "minutes"),
               let minutes = Int(expireDescription[andRange.upperBound..<minutesRange.lowerBound]
                                      .trimmingCharacters(in: .whitespaces))
            {
                return .hours(hours, minutes: minutes)
            } else {
                return .hours(hours, minutes: nil)
            }
        } else if let minutesRange = expireDescription.range(of: "minutes"),
                  let minutes = Int(expireDescription[..<minutesRange.lowerBound]
                                        .trimmingCharacters(in: .whitespaces))
        {
            if let andRange = expireDescription.range(of: "and"),
               let secondsRange = expireDescription.range(of: "seconds"),
               let seconds = Int(expireDescription[andRange.upperBound..<secondsRange.lowerBound]
                                  .trimmingCharacters(in: .whitespaces))
            {
                return .minutes(minutes, seconds: seconds)
            } else {
                return .minutes(minutes, seconds: nil)
            }
        } else {
            Logger.error(
                "Unrecognized BanInterval format", context: [
                    "expireDescription": expireDescription
                ]
            )
            return .unrecognized(content: expireDescription)
        }
    }
}
