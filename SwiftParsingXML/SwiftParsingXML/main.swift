import Foundation

let xml = """
<movie title="Rise of Skywalker" releaseYear="2019">
    <actors>
        <person name="Daisy Ridley" />
        <person name="John Boyega" />
    </actors>
    <director name="JJ Abrams" />
</movie>
"""

struct Movie {
    let title: String
    let releaseYear: Int
    let actors: [Person]
    let director: Person
}

struct Person {
    let name: String
}

protocol ParserDelegate : XMLParserDelegate {
    var delegateStack: ParserDelegateStack? { get set }
    func didBecomeActive()
}

extension ParserDelegate {
    func didBecomeActive() {
    }
}

protocol NodeParser : ParserDelegate {
    associatedtype Item
    var result: Item? { get }
}

class ParserDelegateStack {
    private var parsers: [ParserDelegate] = []
    private let xmlParser: XMLParser

    init(xmlParser: XMLParser) {
        self.xmlParser = xmlParser
    }

    func push(_ parser: ParserDelegate) {
        parser.delegateStack = self
        xmlParser.delegate = parser
        parsers.append(parser)
    }

    func pop() {
        parsers.removeLast()
        if let next = parsers.last {
            xmlParser.delegate = next
            next.didBecomeActive()
        } else {
            xmlParser.delegate = nil
        }
    }
}

class ArrayParser<Parser : NodeParser> : NSObject, NodeParser {
    var result: [Parser.Item]? = []
    var delegateStack: ParserDelegateStack?

    private let tagName: String
    private let parserBuilder: (String) -> Parser?
    private var currentParser: Parser?

    init(tagName: String, parserBuilder: @escaping (String) -> Parser?) {
        self.tagName = tagName
        self.parserBuilder = parserBuilder
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == tagName {
            return
        }

        if let itemParser = parserBuilder(elementName) {
            currentParser = itemParser
            delegateStack?.push(itemParser)
            itemParser.parser?(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == tagName {
            delegateStack?.pop()
        }
    }

    func didBecomeActive() {
        guard let item = currentParser?.result else { return }
        result?.append(item)
    }
}

class PersonParser : NSObject, NodeParser {
    private let tagName: String
    private var name: String!

    var delegateStack: ParserDelegateStack?
    var result: Person?

    init(tagName: String) {
        self.tagName = tagName
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == tagName {
            name = attributeDict["name"]
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == tagName {
            result = Person(name: name)
            delegateStack?.pop()
        }
    }
}

class MovieParser : NSObject, NodeParser {
    private let tagName: String

    private var title: String!
    private var releaseYear: Int!
    private let directorParser = PersonParser(tagName: "director")
    private let actorsParser: ArrayParser<PersonParser>

    var delegateStack: ParserDelegateStack?
    var result: Movie?

    init(tagName: String) {
        self.tagName = tagName
        actorsParser = ArrayParser<PersonParser>(tagName: "actors") { tag in
            guard tag == "person" else { return nil }
            return PersonParser(tagName: tag)
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        print("parsing \(elementName)")

        if elementName == tagName {
            title = attributeDict["title"]
            releaseYear = attributeDict["releaseYear"].flatMap(Int.init)
            return
        }

        switch elementName {
        case "director":
            delegateStack?.push(directorParser)
            directorParser.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        case "actors":
            delegateStack?.push(actorsParser)
            actorsParser.parser(parser, didStartElement: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict)

        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == tagName {
            result = Movie(title: title,
                          releaseYear: releaseYear,
                          actors: actorsParser.result!,
                          director: directorParser.result!)
            delegateStack?.pop()
        }
    }
}

let xmlData = xml.data(using: .utf8)!
let xmlParser = XMLParser(data: xmlData)
let delegateStack = ParserDelegateStack(xmlParser: xmlParser)

let movieParser = MovieParser(tagName: "movie")
delegateStack.push(movieParser)

if xmlParser.parse() {
    print("Done parsing")
    print(movieParser.result!)
} else {
    print("Invalid xml", xmlParser.parserError?.localizedDescription ?? "")
}

