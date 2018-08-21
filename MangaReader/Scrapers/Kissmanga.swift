//
//  Kissmanga.swift
//  MangaReader
//
//  Created by Matt Lin on 8/20/18.
//  Copyright © 2018 Devin Fan. All rights reserved.
//

import Cocoa
import Alamofire
import JavaScriptCore
import WebKit
import CoreData.NSManagedObject

class Kissmanga: Scraper {
    public func get(manga title: String) {
        if Kissmanga.logged_in {
            scrape(manga: title)
        } else {
            login(title)
        }
    }
        
        
    internal func scrape(manga title: String) {
        self._manga = title
        let titleURL = "http://kissmanga.com/Manga/" + title.replacingOccurrences(of: " ", with: "-")
        Alamofire.request(titleURL).responseData { response in
            if let data = response.data, let mangaPage = String(data: data, encoding: .utf8) {
//                    DataManager.add(manga: self._manga!, type: .kissmanga)
                self.parse(mangaPage.replacingOccurrences(of: "\n", with: ""))
            }
        }
    }
        
        
    internal func parse(_ html: String) {
        guard let listingRange = html.range(of: "<table class=\"listing\">.*?</table>", options: .regularExpression) else {
            NSLog("Incorrectly formatted page: Missing table.")
            return
        }
        let table = String(html[listingRange])
        let matches = Kissmanga.CHAPTER.matches(in: table, options: [], range: NSMakeRange(0, table.count))
        
//            var manga: NSManagedObject?
        
        for match in matches.reversed() {
            let row = table[Range(match.range, in: table)!]
            if let urlRange = row.range(of: "(?<=href=\")[^\"]+(?=\")", options: .regularExpression), let chapterRange = row.range(of: "(?<=>)[^<]+(?=<)", options: .regularExpression) {
                let chapter = String(row[chapterRange])
                let url = String(row[urlRange])
                NSLog("Chapter: %@, URL: %@", chapter, url)
//                    if manga == nil {
//                            manga = DataManager.add(chapter: chapter, url: url, to: _manga!)
//                    } else {
//                            DataManager.add(chapter: chapter, url: url, into: manga!)
//                    }
            } else {
                print("Row: \(row)")
            }
        }
    }
        
        
    func fetch(chapter: String, remove: NSViewController, callback: @escaping (NSManagedObject) -> ()) {
        let uri = "http://kissmanga.com" + chapter
        
        Alamofire.request(uri).responseData { response in
            guard let data = response.data, let text = String(data: data, encoding: .utf8) else {
                return
            }
            let matches = Kissmanga.IMAGE_PATTERN.matches(in: text, options: [], range: NSMakeRange(0, text.count))
            
            var images = [String]()
            for match in matches {
                let image = String(text[Range(match.range, in: text)!])
                images.append(image)
            }
            
            self.parse(images: images, chapter: chapter, remove: remove, callback: callback)
        }
    }
        
        
    func parse(images: [String], chapter: String, remove: NSViewController, callback: @escaping (NSManagedObject) -> ()) {
        guard let context = JSContext() else {
            return
        }
        
        Alamofire.request("http://kissmanga.com/Scripts/ca.js").responseData { response in
            Alamofire.request("http://kissmanga.com/Scripts/lo.js").responseData {
                res in
                guard let data = response.data, let cryptoJS = String(data: data, encoding: .utf8), let data2 = res.data, let encoding = String(data: data2, encoding: .utf8) else  {
                    return
                }
                context.evaluateScript(cryptoJS)
                context.evaluateScript(encoding)
                guard let wrap = context.objectForKeyedSubscript("wrapKA") else {
                    return
                }
                
                var urls = [String]()
                
                for image in images {
                    if let link = wrap.call(withArguments: [image]) {
                        urls.append(link.toString())
                    }
                }
                
//                    if !urls.isEmpty, let chapterObj = DataManager.add(images: urls, to: chapter) {
//                        DispatchQueue.main.async {
//                            callback(chapterObj)
//                            remove.removeFromParentViewController()
//                        }
//                    }
            }
            
        }
    }
        
        
    internal func login(_ title: String) {
        let url = URL(string: "http://kissmanga.com")!
        Alamofire.request(url).responseData { response in
            let readType = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "vns_readType1=0"], for: url)
            HTTPCookieStorage.shared.setCookies(readType, for: url, mainDocumentURL: url)
            guard let data = response.data, let utf8Text = String(data: data, encoding: .utf8), let paramaters = Kissmanga.auth(html: utf8Text.replacingOccurrences(of: "\n", with: "")) else {
                NSLog("Already logged in or missing parameters")
                self.scrape(manga: title)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: {
                Alamofire.request("http://kissmanga.com/cdn-cgi/l/chk_jschl", method: .get, parameters: paramaters, encoding: URLEncoding.default, headers: nil).response { _ in
                    self.scrape(manga: title)
                }
            })
            
        }
    }
        
        
    private static func auth(html: String) -> Parameters? {
        guard let scriptRange = html.range(of: "<script.*?</script>", options: .regularExpression) else {
            return nil
        }
        
        let script = html[scriptRange]
        guard let varDefRange = script.range(of: "(?<=var s,t,o,p,b,r,e,a,k,i,n,g,[a-zA-Z], ).*?(?=;)", options: .regularExpression) else {
            return nil
        }
        let varDef = script[varDefRange]
        
        guard let varNameRange = varDef.range(of: "[a-zA-Z]+?(?==)", options: .regularExpression) else {
            print("No var name: \(varDef)" )
            return nil
        }
        let varName = varDef[varNameRange]
        
        guard let context = JSContext() else {
            return nil
        }
        let _ = context.evaluateScript(String("var " + varDef))
        
        guard let actionRange = script.range(of: "(?<== document.getElementById[(]\'challenge-form\'[)];).*?(?=a.value)", options: .regularExpression) else {
            return nil
        }
        let action = script[actionRange]
        let _ = context.evaluateScript(String(action))
     
        guard let varValDict = context.objectForKeyedSubscript(varName), let varVal = varValDict.toDictionary(), let hiddenVar = varVal.first else {
            return nil
        }
        
        let matches = HIDDEN.matches(in: html, options: [], range: NSMakeRange(0, html.count))
        
        var paramaters: Parameters = [:]
        for match in matches {
            let hidden = html[Range(match.range, in: html)!]
            if let name = hidden.range(of: "(?<=name=\").*?(?=\")", options: .regularExpression), let val = hidden.range(of: "(?<=value=\").*?(?=\")", options: .regularExpression) {
                paramaters[String(hidden[name])] = String(hidden[val])
            }
        }
        
        let v = hiddenVar.value as! Double
        let i = Double(Int(v * 10000000000)) / 10000000000
        paramaters["jschl_answer"] = i + 13
        return paramaters
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
        if (try? data.write(to: file)) != nil {
//                DataManager.add(file: "\(manga)/\(chapter)/\(num)", to: url)
        }
    }
        
    var _manga: String?
    var operationQueue = OperationQueue()
    
    static var logged_in = false
    
    static let HIDDEN = try! NSRegularExpression(pattern: "<input type=\"hidden\".*?/>")
    static let IMAGE_PATTERN = try! NSRegularExpression(pattern: "(?<=lstImages.push\\(wrapKA\\(\").*?(?=\"\\)\\))")
    static let CHAPTER = try! NSRegularExpression(pattern: "<a.*?</a>")
}
