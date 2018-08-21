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
                let url = String(format: Bato.BATO_URL, id)
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
    
    
    func fetch(chapter: String, remove: NSViewController, callback: @escaping (_ chapter: NSManagedObject) -> ()) {
        let chapterURL = String(format: Bato.BATO_URL, chapter)
        NSLog("Fetch: \(chapterURL)")
        Alamofire.request(chapterURL).responseData { response in
            guard let data = response.data, let chapterText = String(data: data, encoding: .utf8) else {
                NSLog("No chapter data")
                return
            }

            let stripped = chapterText.replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\r", with: "")
            guard let imagesRange = stripped.range(of: "(?<=var images =) +\\{[^\\}]+\\}", options: .regularExpression),
                let imageJSON = String(stripped[imagesRange]).data(using: .utf8),
                let imageObject = try? JSONSerialization.jsonObject(with: imageJSON, options: .mutableLeaves),
                let imageInfo = imageObject as? [String: String] else {
                    print("No images: \(stripped)")
                    return
            }
            let keys = Array(imageInfo.keys).sorted(by: { (first, second) -> Bool in
                return Int(first)! < Int(second)!
            })
            for key in keys {
                print("Image \(key): \(imageInfo[key]!)")
            }
        }

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
    static let BATO_URL = "https://bato.to%@"
    static let SEARCH_URL = "https://bato.to/search"
    static let HEADERS: HTTPHeaders = [
        "referer": "https://bato.to",
        "dnt": "1"
    ]
    static let WORD_PATTERN = try! NSRegularExpression(pattern: "</?[^<>]+>")
}
