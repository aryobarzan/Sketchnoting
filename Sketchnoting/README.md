#  Sketchnoting

## Installing the app and running
To build and run the application on a physical iPad or on an iPad simulator, follow these steps: (Note that you need a Mac and the Xcode software)

- Open the Sketchnoting project in Xcode, find the 'Pods' project and remove all references to this project
- Close Xcode
- Open up a Terminal and change your current working directory to the project's main directory (the directory which contains the file 'Podfile')
- Run 'pod install' (You first need to install Cocoapods on your machine to make use of the pod command)
- Open the Sketchnoting workspace file (NOT project) that has been generated in the main folder now in Xcode: Upon first opening the workspace, Xcode may take a while to index the project's files before you can build it
- In case it says "No scheme" next to the play/stop buttons at the top left of Xcode, select "No scheme">"New scheme...">"Create"
- Select your prefered simulator / physical device to build the app for (note - iPad only)
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
