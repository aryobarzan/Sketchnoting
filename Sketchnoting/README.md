#  Sketchnoting

To build and run the application on a physical iPad or on an iPad simulator, follow these steps: (Note that you need a Mac and the Xcode software)

- Delete 'Podfile' file (but keep a copy somewhere) & 'Podfile.lock' file & 'Pods' folder in the project's main folder
- Open the Sketchnoting project in Xcode, find the 'Pods' project and remove all references to this project
- Close Xcode
- Open up a Terminal and change your current working directory to the project's main directory
- Run 'pod init' & 'pod install'
- Paste the old Podfile (which you deleted in the first step) in the project folder and re-run 'pod install'
- Open the Sketchnoting workspace file (NOT project) in Xcode and build the project (cmd+B)
- Run the app! (In case you want to run the app on a physical device, open the root 'Sketchnoting' file in the Project Navigator in Xcode and setup an Apple Provisioning Profile under General>Signing)

--------------

There is documentation in the various .swift files, but the general structure of the project is as follows:

- Under the root 'Sketchnoting' folder, the required application files, as well as the interface files (storyboards) are included
- Under the Sketchnoting/Application/Views folder, the various interface (.xib) files and the corresponding controller files (.swift) for the custom UI views of the app are contained
- Under the Sketchnoting/Application/Helpers folder, OCRHelper.swift contains the post-processing functions for the text recognition feature and SemanticHelper.swift contains the functions for the semantic annotation API calls to Dbpedia Spotlight
- Under the Sketchnoting/Application/Data folder, the custom data classes used by the app are contained, which are also coded to be encodable/decodable for persistence
- The two remaining files under the Sketchnoting/Application folder are ViewController and SketchNoteViewController: the former handles all interactions on the home page of the app, while the latter handles every action on the note editing page

Outside of the Application folder, there are various other folders related to the third-party libraries used by the app (see CREDITS.md), except for the Extensions folder, which adds some extra functions to existing Swift classes


The main code is thus under the Sketchnoting/Application folder
