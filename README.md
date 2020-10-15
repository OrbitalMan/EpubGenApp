# EpubGenApp
Utility for generating epub with smil timings from google docs

1) Download Chapter folder from google doc. 
2) Rename each paragraph as paragraph_x_y where x is chapter number and y is paragraph number
3) Open paragraph document in google doc, File > Donwload > Epub Publication
4) Put each epub directly to its paragraph folder in (1)
5) Rename each mp3 file in paragraphs to original.mp3
5) Navigate to chapter folder and open command line
6) Run command for every paragraph: `cd paragraph_x_y && lame -b44 original.mp3 audio.mp3 && cd ..`
7) Open EpubGenApp. Select your paragraph_x_y directory. Timing, audio, name should autofill.
8) Copy title for paragraph from google doc / epub and put it in title field.
9) Click compose
10) Open generated/paragraph_x_y/OEBPS/Text/paragraph_x_y.xhtml to check its markup.

Result for android will be stored in generated_raw, ios: generated folder.

Known issues: 
If app gives error that span count != timing count it means that timing file is not correct
If app gives error that text not found in other text it means that program cannot generate it for some reason.

One of issues can be highlited text covering parts from different articles.
To fix this open .xhtml file from paragraph_x_y with some text editor and open original google doc.
Look at the doc and change color of smaller part to fit previous/next span by setting same css classes to it.
