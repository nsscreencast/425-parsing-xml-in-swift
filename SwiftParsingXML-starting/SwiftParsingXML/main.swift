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



