//
//  Scraper.swift
//  Manga Reader
//
//  Created by Matt Lin on 12/31/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import Cocoa
import CoreData.NSManagedObject


enum ScraperType: String {
    case bato = "bato"
    case kissmanga = "kissmanga"
}


@objc protocol Scraper {
    /**
     Public method to be called to fetch manga.
     
     - parameter manga: Title of manga.
     */
    func get(manga : String)
    
    
    /**
     Get manga title page.
     
     - Important:
     Calls parse to get chapter data.
     
     - parameter manga: Title of manga to be scraped.
     */
    func scrape(manga: String)
    
    
    /**
     Parse manga title page for information about each chapter.
     
     - parameters:
        - _ Manga html.
     */
    func parse(_: String)
    
    
    /**
     Fetch images from chapter.
     
     - parameters:
         - chapter: Chapter id to be appened to url.
         - remove: Loading view controller.
         - callback: Called after images have been fetched.
         - imageSet: Set of images that have been loaded and should be displayed.
     */
    func fetch(chapter: String, remove: NSViewController, callback: @escaping (_ chapter: NSManagedObject) -> ())
    
    
    func download(data: Data, url: String, num: Int, chapter: String, manga: String)
    
    @objc optional func login(manga : String)
}
