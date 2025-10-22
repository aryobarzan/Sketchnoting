#  Sketchnoting

Sketchnoting is a note-taking app designed for iPad. Its premise is to support both handwriting and sketching in a note using an Apple Pencil, though it also includes an extensive set of other features aimed at helping students with their studies:
- **Text Recognition**: the user's handwriting is automatically recognized in the background. This allows the user to not only copy it to their clipboard, but also to enable other features, such as the app's search and semantic annotation functionalities.
- **Drawing Recognition:** the user can draw basic shapes and objects, which Sketchnoting will recognize and label in the background. Subsequently, the user can search for their notes by using keywords related to their sketches. For example, if their drawing includes a lightning shape, they can search for "lightning" to retrieve the note.
- **PDF Import**: the user can import PDF files, which are integrated into their notes.
- **Pagination**: a note can have multiple pages.
- **Semantic Annotation**: The textual content of a note is used to extract named concepts and to fetch relevant documents, which the user can directly view within the app. Sources include Wikipedia articles, but also more domain-specific ones, such as [BioPortal](https://bioportal.bioontology.org/) and [CHEBI](https://www.ebi.ac.uk/chebi/).
- **Search**: the user can rely on various aspects of their notes to search for them.
    - Textual content: the recognized handwritten text and the content of imported PDFs are used for the search indexing.
    - Drawings: the user can search for drawings in their notes, based on their labels.
    - Semantic annotations: if, for example, a Wikipedia article has been fetched due to the mention of a named concept in the note, the content of that article (title, body) are also used for the search indexing.
- **Drawing Search**: instead of typing the name of a drawing to search for the containing note(s), the user can also draw the shape in a dedicated panel, which will be automatically recognized and searched for.
- **Semantic Search**: in addition to its standard approach based on lexical search, with the usage of TF-IDF for the indexing, the user can also use semantically related keywords to search for their notes. For example, if their note contains the word "Shakespeare", they could look it up using the label "theatre play", even if the latter is not explicitly mentioned anywhere in the note.
    - This feature is enabled using a word embedding (FastText), which is used to represent the search keywords and the textual content of a note as vectors. The word vectors are then compared for semantic similarity using the cosine distance.
    - The search also performs various pre-processing steps, such as tokenization and lematization, as well as word clustering in case of a longer search query. The latter leads to separate searches.
- **Question-Answering**: when performing a search, the app will also attempt to recognize whether the user's query forms a question. If so, it will attempt to directly answer their question by applying a question-answering model (DistillBERT).
- **Hybrid Search**: the lexical search, semantic search and question-answering do not have to be explicitly selected by the user. Rather, they rely on a singular text field to enter their query, with Sketchnoting automatically performing the various search types when appropriate.
- **Search Filtering**: instead of entering a search query, the user can also select filters (time frame, note length, drawings, related documents).
- **Graph View**: the search results of the "Search Filtering" feature are displayed in a visual manner, using a [force-directed graph](https://en.wikipedia.org/wiki/Force-directed_graph_drawing). This graph view not only highlights the relations between the notes, but they are also displayed in a manner such that their visualization (nodes) do not overlap.
- **Similar Notes**: the user can also select a note in their library and choose to look for related notes in their library.
    - The note similarity is enabled as follows:
        1. The main keywords are extracted from each note's textual content using TextRank.
            - A text summarization approach based on TextRank and PageRank is also integrated, though the keyword extraction approach is enabled by default due to its lower memory cost.
        2. The summarized text is tokenized to words, with the latter being lemmatized.
        3. Stop words and repetitions are removed.
        4. The FastText word embedding is used to represent each word as a vector.
        5. The vectors are averaged to obtain a single vector representation for the entire note. ("centroid")
        6. Two notes are then compared to each other based on the cosine distance between their centroids.
    - In addition to the centroid-based method, a matrix-based approach is also integrated. Here, rather than averaging the word vectors, they are all retained as part of a matrix representation. The similarity is then determined by multiplying the notes' respective matrices and by finally computing the resulting matrix' norm.
        - By default, the centroid-based approach is enabled, as the matrix approach has a much higher memory cost and its accuracy gain over the centroid approach is not that significant.
- **Library Organization**: the user can organize their notes into folders, with support for nested folders. When importing an external note or PDF into their library, Sketchnoting will attempt to suggest an existing folder in which it can be stored by relying on the "Similar Notes" functionality.
- **Note Sharing**: Sketchnoting integrates Apple's "Multipeer Connectivity" framework to support sharing notes between nearby devices without the need for user accounts or online connectivity.

Sketchnoting was developed as part of a Master's thesis at the University of Luxembourg. If you wish to learn more about the project, feel free to contact me for a copy of the thesis.

## State of the App

Note that this application was developed in 2021, and it has not received any updates ever since. As such, many of its functionalities may no longer work as intended with newer versions of Swift and Xcode, and the UI itself may also appear different from the original designs.

Some minimal work has been done to update the third-party packages and fix some Swift-related issues, such that the app can be built using the latest Xcode version.

## Installing the app and running
To build and run the application on a physical iPad or on an iPad simulator, follow these steps: (Note that you need a macOS device and Xcode)

- Open the Sketchnoting project in Xcode, find the 'Pods' project and remove all references to this project.
- Close Xcode.
- Open up a Terminal and change your current working directory to the project's main directory (the directory which contains the file 'Podfile').
- Run 'pod install' (You first need to install Cocoapods on your machine to make use of the pod command).
- Open the Sketchnoting workspace file (NOT project) that has been generated in the main folder now in Xcode: upon first opening the workspace, Xcode may take a while to index the project's files before you can build it.
- In case it says "No scheme" next to the play/stop buttons at the top left of Xcode, select "No scheme">"New scheme...">"Create".
- Select your prefered simulator / physical device to build the app for (note - iPad only).
- Run the app! (In case you want to run the app on a physical device, open the root 'Sketchnoting' file in the Project Navigator in Xcode and setup an Apple Provisioning Profile under General>Signing)

--------------
## Code structure
There is documentation in the various .swift files, but the general structure of the project is as follows:

- Under the root 'Sketchnoting' folder, the required application files, as well as the interface files (views/storyboards) are included
- Under the Sketchnoting/Application/Views folder, the various interface (.xib) files and the corresponding controller files (.swift) for the custom UI views of the app are contained
- Under the Sketchnoting/Application/Helpers folder, OCRHelper.swift contains the post-processing functions for the text recognition feature and SemanticHelper.swift contains the functions for the semantic annotation API calls to Dbpedia Spotlight
- Under the Sketchnoting/Application/Data folder, the custom data classes used by the app are contained, which are also coded to be encodable/decodable for persistence. The main Model NotesManager class holds all the user's data and is accessed by the application's controller to fetch/update/delete notes
- The two remaining files under the Sketchnoting/Application folder are ViewController and SketchNoteViewController: the former handles all interactions on the home page of the app, while the latter handles every action on the note editing page

Outside of the Application folder, there are various other folders related to the third-party libraries used by the app (see CREDITS.md), except for the Extensions folder, which adds some extra functions to existing Swift classes.

The main source code is under the Sketchnoting/Application folder.
