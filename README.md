# SurveyThread
 A multi-threaded File System survey engine

If you ever need to perform a recursive search over a tree on the filesystem, here's something to help you not re-invent the wheel.

* Multithreaded: It is a subclass of Thread. It instantiates a new instance of itself for every new folder it encounters. You can configure maximum active concurrent threads. Works in cooperative mode.
* Conditional: File and folder match are RegEx-powered.
* Database-powered: Accumulates results in an in-memory SQLite Database: One table for files, one for folders. You can save the database to a file or keep working in-memory.
* Asynchronous:  You start it and you get an event when it's done surveying.

Check out the included project on how to use it. 
Fine-tune maximum concurrent threads and thread priority to find a balance between application responsiveness and survey speed.
Works for both Desktop and Console.