//
//  Bato.swift
//  Manga Reader
//
//  Created by Matt Lin on 12/31/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

//import UIKit.UIScrollView
import Alamofire
import CoreData.NSManagedObject

class Bato: Scraper {
    public func get(manga title: String) {
        if Bato.logged_in {
//            scrape(manga: title)
        } else {
            login(title)
        }
    }
    
    
    internal func find(manga title: String) {
        let paramaters: Parameters = [
            "q": title,
        ]
        
        Alamofire.request(Bato.SEARCH_URL, method: .get, parameters: paramaters, encoding: URLEncoding.default, headers: Bato.HEADERS).responseData { response in
            if let data = response.data, let text = String(data: data, encoding: .utf8), let start = text.range(of: "<div id=\"series-list\"") {
                print("Start", start)
                let tableText = text[start.lowerBound...]
                guard let firstResultRange = tableText.range(of: "<a.*?class=\"item-title\"[^<]+", options: .regularExpression) else {
                    NSLog("Missing results")
                    return
                }
                let firstResult = tableText[firstResultRange]
                guard let idRange = firstResult.range(of: "(?<=href=\")[^\"]+", options: .regularExpression), let titleRange = firstResult.range(of: "(?<=>).*$", options: .regularExpression) else {
                    print("Missing id or title")
                    print(firstResult)
                    return
                }
                let id = String(firstResult[idRange])
                let title = String(firstResult[titleRange])
                self._manga = title
                print("Info \(id), \(title)")
                let url = String(format: Bato.MANGA_URL, id)
                self.scrape(manga: url)
            } else {
                NSLog("No chapter results")
            }
        }
    }
    
    
    internal func scrape(manga url: String) {
        guard let link = url.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed) else {
            NSLog("Failed to format link")
            return
        }
        Alamofire.request(link).responseData { response in
            guard let data = response.data, let text = String(data: data, encoding: .utf8) else { return }
            NSLog("Parsing")
            self.parse(text)
        }
    }
    
    
    internal func parse(_ html: String) {
        let stripped = html.replacingOccurrences(of: "\n", with: "")
        guard let tableStart = stripped.range(of: "<div class=\"main\""), let tableEnd = stripped.range(of: "<!-- /chapters -->") else {
            NSLog("Missing table start or end")
            print(stripped)
            return
        }
        
        let table = String(stripped[tableStart.lowerBound...tableEnd.lowerBound])

        let matches = Bato.TABLE_ROW.matches(in: table, options: [], range: NSMakeRange(0, table.count))
        
        if matches.isEmpty {
            NSLog("Missing chapters")
            return
        }

//        var manga: NSManagedObject? = nil
        for match in matches.reversed() {
            let row = table[Range(match.range, in: table)!]
            guard let infoRange = row.range(of: "<a.*?</a>", options: .regularExpression) else {
                NSLog("Missing info for row: \(row)")
                return
            }
            let info = row[infoRange]
            guard let idRange = info.range(of: "(?<=href=\")[^\"]+", options: .regularExpression), let titleRange = info.range(of: "(?<=>).*(?=</a>)", options: .regularExpression) else {
                NSLog("Missing chapter url or chapter title")
                return
            }
            let chapterId = String(info[idRange])
            var chapterTitle = String(info[titleRange])
            chapterTitle = Bato.WORD_PATTERN.stringByReplacingMatches(in: chapterTitle, options: [], range: NSMakeRange(0, chapterTitle.count), withTemplate: "")
            let components = chapterTitle.components(separatedBy: .whitespacesAndNewlines)
            chapterTitle = components.filter { !$0.isEmpty }.joined(separator: " ")
            print("Info: \(chapterId), \(chapterTitle)")
//            if manga == nil {
//                manga = DataManager.add(chapter: chapter, url: url, to: _manga!)
//            } else {
//                DataManager.add(chapter: String(link[titleRange]), url: url, into: manga!)
//            }
        }
    }
    
    
    func parse(chapter: String) -> [String]? {
        let stripped = chapter.replacingOccurrences(of: "\n", with: "")
        guard let selectorRange = stripped.range(of: "<select name=\"page_select\" id=\"page_select\".*?</select>", options: .regularExpression) else {
            return nil
        }
        
        let selector = String(stripped[selectorRange])
        
        let matches = Bato.SELECTOR_OPTION.matches(in: selector, options: [], range: NSMakeRange(0, selector.count))
        
        if matches.isEmpty {
            return nil
        }
        
        return matches.map { (match) -> String in
            return String(selector[Range(match.range, in: selector)!])
        }
    }
    
    
    func parseSingle(chapter: String) -> [String]? {
        let stripped = chapter.replacingOccurrences(of: "\n", with: "")
        guard let range = stripped.range(of: "<div .*?>( ?<img src=[\"\'].*?/><br ?/>)+", options: .regularExpression) else { return nil }
        let div = String(stripped[range])
        return nil
//        let matches = BatoOperation.IMAGE_PATTERN.matches(in: div, options: [], range: NSMakeRange(0, div.count))
//        guard !matches.isEmpty else { return nil }
//
//        var images = [String]()
//        for match in matches {
//            let image = String(div[Range(match.range, in: div)!])
//            images.append(image)
//        }
//
//        return images
    }
    
    
    func fetch(chapter: String, remove: NSViewController, callback: @escaping (_ chapter: NSManagedObject) -> ()) {
//        let group = DispatchGroup()
//        group.enter()
//        BatoOperation._group = group
//        let params = BatoOperation.splitHTMLParam(url: chapter)
//
//        Alamofire.request(BatoOperation.IMAGE_URL, method: .get, parameters: params, encoding: URLEncoding.default, headers: BatoOperation.HEADERS).responseData { response in
//            if let data = response.data, let chapter = String(data: data, encoding: .utf8) {
//                if let images = self.parse(chapter: chapter) {
//                BatoOperation._data = [String](repeating: "", count: images.count)
//                for (ind, image) in images.enumerated() {
//                    group.enter()
//                    self.operationQueue.addOperation(BatoOperation(url: image, num: ind))
//                    }
//                } else if let images = self.parseSingle(chapter: chapter) {
//                    BatoOperation._data = images
//                }
//            }
//            group.leave()
//        }
    
        
//        group.notify(queue: .main) {
//            if let chapterObj = DataManager.add(images: BatoOperation._data, to: chapter) {
//                DispatchQueue.main.async {
//                    callback(chapterObj)
//                    remove.removeFromParentViewController()
//                }
//                BatoOperation._data = []
//            }
//            BatoOperation._group = nil
//            print("Done: \(BatoOperation._data.count)")
//        }
    }
    
    
    internal func login(_ title: String) {
        let loginURL = "https://sso.anyacg.com/gateway/login"
        
        let baseURL = URL(string: "https://bato.to")!
        let suppress = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "suppress_webtoon=t"], for: baseURL)
        HTTPCookieStorage.shared.setCookies(suppress, for: baseURL, mainDocumentURL: baseURL)
        
        let parameters: Parameters = [
            "email": "bobmagee47@gmail.com",
            "pass0": "whatever1A"
        ]
        Alamofire.request(loginURL, method: .post, parameters: parameters, encoding: URLEncoding(destination: .httpBody), headers: nil).response { response in
            print("Logged in")
            Bato.logged_in = true
//            debugPrint(response)
            self.find(manga: title)
        }
    }
    
    
    func download(data: Data, url: String, num: Int, chapter: String, manga: String) {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let mangaURL = docURL.appendingPathComponent(manga, isDirectory: true)
        let chapterURL = mangaURL.appendingPathComponent(chapter, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: chapterURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            let err = error as NSError
            if err.code != 516 {
                return
            }
        }
        let file = chapterURL.appendingPathComponent("\(num)")
//        if (try? data.write(to: file)) != nil {
//            DataManager.add(file: "\(manga)/\(chapter)/\(num)", to: url)
//        }
    }
    
    var operationQueue = OperationQueue()
    var _manga: String?
    
    static var logged_in = false
    
    static let TABLE_ROW = try! NSRegularExpression(pattern: "<div.*?</div>")
    static let SELECTOR_OPTION = try! NSRegularExpression(pattern: "(?<=<option value=\").*?(?=\")")
    static let MANGA_URL = "https://bato.to%@"
    static let SEARCH_URL = "https://bato.to/search"
    static let HEADERS: HTTPHeaders = [
        "referer": "https://bato.to",
        "dnt": "1"
    ]
    static let WORD_PATTERN = try! NSRegularExpression(pattern: "</?[^<>]+>")
}
