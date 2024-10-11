#tag Class
Protected Class SurveyThread
Inherits Thread
	#tag Event
		Sub Run()
		  while GetActiveThreads >= ThreadLimit // Thread has been created but it's not active
		    Current.Sleep(150)
		    if KillFlags.Value(SurveyID).BooleanValue = true then Return
		  wend
		  
		  
		  if not ParentThread then ActiveThreadIncrement
		  
		  dim RegExMatcher as RegEx
		  dim Match as RegExMatch
		  
		  InsertFolderRecord(RootFolder , "")
		  
		  try
		    
		    for each obj as FolderItem in RootFolder.Children(FollowLinks)
		      
		      if KillFlags.Value(SurveyID).BooleanValue = true then exit for
		      
		      if obj.IsFolder then  // it is a folder
		        
		        if FolderMatchCondition = "" then // survey every folder
		          
		          if Recursive then RecursionThreads.Add(new SurveyThread(obj , me))
		          
		        else 
		          
		          RegExMatcher = new RegEx
		          RegExMatcher.SearchPattern = FolderMatchCondition
		          
		          Match = RegExMatcher.Search(obj.name)
		          
		          if not IsNull(Match) then 
		            if Recursive then RecursionThreads.Add(new SurveyThread(obj , me))
		          end if
		          
		        end if
		        
		      else // it is a file
		        
		        if FileMatchCondition = "" then // survey every file
		          
		          InsertFileRecord(obj , "")
		          
		        else
		          
		          RegExMatcher = new RegEx
		          RegExMatcher.SearchPattern = FileMatchCondition
		          
		          Match = RegExMatcher.Search(obj.name)
		          
		          if not IsNull(Match) then 
		            InsertFileRecord(obj , "")
		          end if
		          
		        end if
		        
		        
		      end if
		      
		    next
		    
		  Catch ioe as IOException
		    SetFatalError(ioe.Message)
		    KillSurvey
		  Catch noe as NilObjectException
		    SetFatalError("Nil object exception")
		    KillSurvey
		  end try
		  
		  if not ParentThread then ActiveThreadDecrement
		  
		  // loop to watch for end of survey
		  
		  dim ZeroSamples as Integer
		  
		  if ParentThread then
		    
		    while SurveyState = SurveyStates.Running
		      
		      If ActiveThreadCounters.Value(SurveyID).IntegerValue = 0 then //every thread has ended
		        
		        if ZeroSamples < 5 then // sample thread counter one more time. this condition prevents false survey completed events
		          
		          ZeroSamples = ZeroSamples + 1
		          
		        else  // enough thread samples reading 0, we're probably done
		          
		          if KillFlags.Value(SurveyID).BooleanValue then // kill or fatal error
		            
		            if GetFatalError.IsEmpty then 
		              SurveyState = SurveyStates.Killed
		            else
		              SurveyState = SurveyStates.FatalError
		            end if
		            
		          else // everyone's done
		            
		            SurveyState = SurveyStates.Completed
		            
		          end if 
		          
		          exit While
		          
		        end if
		        
		      else
		        
		        ZeroSamples = 0  // reset zero samples
		        
		      end if
		      
		      Current.Sleep(250)
		      
		    wend
		    
		    
		    Redim RecursionThreads(-1)  // clear all residual thread objects
		    TimestampEnd = DateTime.Now
		    
		    RaiseEvent SurveyFinished(SurveyState , GetFatalError)
		    
		  end if
		  
		  
		  
		End Sub
	#tag EndEvent

	#tag Event
		Sub UserInterfaceUpdate(data() as Dictionary)
		  // not exposed
		  
		  
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h21
		Private Sub ActiveThreadDecrement()
		  ActiveThreadCounters.Value(SurveyID) = ActiveThreadCounters.Value(SurveyID).IntegerValue - 1
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ActiveThreadIncrement()
		  ActiveThreadCounters.Value(SurveyID) = ActiveThreadCounters.Value(SurveyID).IntegerValue + 1
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor()
		  SurveyState = SurveyStates.Initialized
		  Type = Types.Cooperative
		  
		  SurveyID = GenerateSurveyID
		  
		  ParentThread = true
		  
		  if IsNull(KillFlags) then KillFlags = new Dictionary
		  if IsNull(SurveyDatabases) then SurveyDatabases = new Dictionary
		  if IsNull(ActiveThreadCounters) then ActiveThreadCounters = new Dictionary
		  if IsNull(FatalErrors) then FatalErrors = new Dictionary
		  
		  ResetSurveyProperties
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Constructor(iRootFolder as FolderItem, byref iParentThread as SurveyThread)
		  SurveyState = SurveyStates.Worker
		  
		  Type = iParentThread.Type
		  Priority = iParentThread.Priority
		  ThreadLimit = iParentThread.ThreadLimit
		  
		  SurveyID = iParentThread.SurveyID
		  ParentThread = False
		  Recursive = true
		  
		  RootFolder = new FolderItem(iRootFolder)
		  
		  ParentRootFolder = iParentThread.ParentRootFolder
		  FileMatchCondition = iParentThread.FileMatchCondition
		  FolderMatchCondition = iParentThread.FolderMatchCondition
		  FollowLinks = iParentThread.FollowLinks
		  
		  
		  Start
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Destructor()
		  if ParentThread Then
		    
		    ActiveThreadCounters.Remove(SurveyID)
		    FatalErrors.Remove(SurveyID)
		    KillFlags.Remove(SurveyID)
		    SurveyDatabases.Remove(SurveyID)
		    
		  End if
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function GenerateSurveyID() As String
		  dim n as Integer
		  n = System.Microseconds
		  
		  Return n.ToString
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetActiveThreads() As integer
		  Return ActiveThreadCounters.Value(SurveyID).IntegerValue
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetDatabase() As SQLiteDatabase
		  Return SQLiteDatabase(SurveyDatabases.Value(SurveyID))
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetFatalError() As String
		  Return FatalErrors.Value(SurveyID).StringValue
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetSurveyDuration() As integer
		  //select CAST(strftime('%s', max(surveystamp)) as integer) - CAST(strftime('%s',min(surveystamp)) as integer) from files
		  
		  if IsNull(TimestampEnd) then Return -1
		  
		  Return TimestampEnd.SecondsFrom1970 - TimestampStart.SecondsFrom1970
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function GetSurveyState() As SurveyStates
		  Return SurveyState
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub InitializeDatabase()
		  dim db as new SQLiteDatabase // in-memory
		  
		  db.Connect
		  
		  db.ExecuteSQL(InitDatabaseScript)
		  
		  SurveyDatabases.Value(SurveyID) = db
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub InsertFileRecord(FileObject as FolderItem, ErrorMsg as String)
		  dim folder_relative as String = FileObject.Parent.NativePath.Right(FileObject.Parent.NativePath.Length - ParentRootFolder.Length)
		  
		  if folder_relative.Trim = "" then
		    if TargetWindows then folder_relative = "\" else folder_relative = "/"
		  end if
		  
		  
		  GetDatabase.ExecuteSQL("INSERT INTO files (rootfolder_absolute , folder_absolute , folder_relative , file , extension , size , createstamp , modifystamp , permissions , group_owner , user_owner , isalias , isvisible , shellpath , error) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)" , _
		  ParentRootFolder , _
		  FileObject.Parent.NativePath , _
		  folder_relative , _
		  FileObject.Name , _
		  NullableString(FileObject.Extension.Uppercase) , _
		  FileObject.Length , _
		  FileObject.CreationDateTime , _
		  FileObject.ModificationDateTime , _
		  FileObject.Permissions , _
		  NullableString(FileObject.Group) , _
		  NullableString(FileObject.Owner) , _
		  FileObject.IsAlias , _
		  FileObject.Visible , _
		  FileObject.ShellPath , _
		  NullableString(ErrorMsg))
		  
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub InsertFolderRecord(FolderObject as FolderItem, ErrorMsg as String)
		  dim folder_relative as String = FolderObject.NativePath.Right(FolderObject.NativePath.Length - ParentRootFolder.Length)
		  
		  if folder_relative.Trim = "" then
		    if TargetWindows then folder_relative = "\" else folder_relative = "/"
		  end if
		  
		  GetDatabase.ExecuteSQL("INSERT INTO folders (rootfolder_absolute , folder_absolute , folder_relative , createstamp , modifystamp , permissions , group_owner , user_owner , isalias , isvisible , shellpath , error) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)" , _
		  ParentRootFolder , _
		  FolderObject.NativePath , _
		  folder_relative , _
		  FolderObject.CreationDateTime , _
		  FolderObject.ModificationDateTime , _
		  FolderObject.Permissions , _
		  NullableString(FolderObject.Group) , _
		  NullableString(FolderObject.Owner) , _
		  FolderObject.IsAlias , _
		  FolderObject.Visible , _
		  FolderObject.ShellPath , _
		  NullableString(ErrorMsg))
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub KillSurvey()
		  if GetSurveyState = SurveyStates.Running or GetSurveyState = SurveyStates.Worker then
		    KillFlags.Value(SurveyID) = true
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function NullableString(value as string) As Variant
		  if value.IsEmpty then
		    Return nil
		  else
		    Return value
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ResetSurveyProperties()
		  SetFatalError("")
		  KillFlags.Value(SurveyID) = False
		  ActiveThreadCounters.Value(SurveyID) = 0
		  InitializeDatabase
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SaveSurvey(File as FolderItem)
		  if SurveyState <> SurveyStates.Completed then
		    Raise new RuntimeException("Cannon save survey database while in current state" , 201)
		  end if
		  
		  
		  if IsNull(GetDatabase) then Raise new RuntimeException("No database in survey" , 205)
		  
		  if IsNull(file) then Raise new RuntimeException("File path is invalid" , 202)
		  if file.Exists then Raise new RuntimeException("File already exists" , 203)
		  if file.IsFolder then Raise new RuntimeException("File is actually a folder" , 204)
		  
		  dim TargetDB as new SQLiteDatabase
		  
		  TargetDB.DatabaseFile = file
		  
		  try
		    
		    TargetDB.CreateDatabase
		    GetDatabase.BackUp(TargetDB , nil , -1)
		    
		  Catch ioe as IOException
		    
		    Raise new RuntimeException(ioe.Message , 206)
		    
		  Catch dbe as SQLiteException
		    
		    Raise new RuntimeException(dbe.Message , 207)
		    
		  end try
		  
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SetFatalError(msg as string)
		  FatalErrors.Value(SurveyID) = msg
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetMaxActiveWorkers(MaxWorkers as Integer)
		  Dim MaxWorkersLimit as Integer = 40
		  
		  if MaxWorkers < 2 or MaxWorkers > MaxWorkersLimit then 
		    Raise new RuntimeException("Max Workers value should be between 1 and " + MaxWorkersLimit.ToString , 301)
		  end if
		  
		  
		  ThreadLimit = MaxWorkers
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Start()
		  // Calling the overridden superclass method.
		  Super.Start()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub StartSurvey(iRootFolder as FolderItem, iRecursive as Boolean, iFileMatchCondition as String, iFolderMatchCondition as string, iFollowLinks as boolean)
		  if SurveyState = SurveyStates.Running then raise new RuntimeException("A new survey cannot be started while another is running" , 100)
		  
		  if IsNull(iRootFolder) then Raise new RuntimeException("Invalid Root folder" , 101)
		  if not iRootFolder.Exists then Raise new RuntimeException("Root folder does not exist" , 102)
		  if not iRootFolder.IsFolder then Raise new RuntimeException("Root folder is not actually a folder" , 103)
		  if not iRootFolder.IsReadable then Raise new RuntimeException("Root folder is not readable" , 104)
		  if ThreadLimit < 1 then Raise new RuntimeException("Thread Limit parameter needs to be higher" , 105)
		  
		  SurveyState = SurveyStates.Running
		  
		  RootFolder = new FolderItem(iRootFolder)
		  if ParentThread then ParentRootFolder = RootFolder.NativePath
		  
		  Recursive = iRecursive
		  FileMatchCondition = iFileMatchCondition
		  FolderMatchCondition = iFolderMatchCondition
		  FollowLinks = iFollowLinks
		  
		  
		  ResetSurveyProperties
		  
		  TimestampStart = DateTime.Now
		  TimestampEnd = nil
		  
		  Start
		  
		  
		End Sub
	#tag EndMethod


	#tag Hook, Flags = &h0
		Event SurveyFinished(EndState as SurveyThread.SurveyStates, ErrorMessage as String)
	#tag EndHook


	#tag Property, Flags = &h21
		Private Shared ActiveThreadCounters As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private Shared FatalErrors As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private FileMatchCondition As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private FolderMatchCondition As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private FollowLinks As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private Shared KillFlags As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private ParentRootFolder As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private ParentThread As Boolean = false
	#tag EndProperty

	#tag Property, Flags = &h21
		Private RecursionThreads() As SurveyThread
	#tag EndProperty

	#tag Property, Flags = &h21
		Private Recursive As Boolean = false
	#tag EndProperty

	#tag Property, Flags = &h21
		Private RootFolder As FolderItem
	#tag EndProperty

	#tag Property, Flags = &h21
		Private Shared SurveyDatabases As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private SurveyID As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private SurveyState As SurveyStates
	#tag EndProperty

	#tag Property, Flags = &h21
		Private ThreadLimit As Integer = 10
	#tag EndProperty

	#tag Property, Flags = &h21
		Private TimestampEnd As DateTime
	#tag EndProperty

	#tag Property, Flags = &h21
		Private TimestampStart As DateTime
	#tag EndProperty


	#tag Constant, Name = InitDatabaseScript, Type = String, Dynamic = False, Default = \"CREATE TABLE files (\r\nrowid INTEGER PRIMARY KEY AUTOINCREMENT \x2C\r\nsurveystamp DATETIME DEFAULT CURRENT_TIMESTAMP \x2C\r\nrootfolder_absolute TEXT NOT NULL \x2C \r\nfolder_absolute TEXT NOT NULL \x2C\r\nfolder_relative TEXT \x2C\r\nfile TEXT NOT NULL \x2C \r\nextension TEXT \x2C \r\nsize INTEGER NOT NULL \x2C \r\ncreatestamp DATETIME \x2C \r\nmodifystamp DATETIME \x2C \r\npermissions INTEGER \x2C \r\ngroup_owner TEXT \x2C \r\nuser_owner TEXT \x2C \r\nisalias BOOLEAN NOT NULL \x2C \r\nisvisible BOOLEAN NOT NULL \x2C\r\nshellpath TEXT \x2C\r\nerror TEXT);\r\n\r\nCREATE TABLE folders (\r\nrowid INTEGER PRIMARY KEY AUTOINCREMENT \x2C\r\nrootfolder_absolute TEXT NOT NULL \x2C \r\nfolder_absolute TEXT NOT NULL \x2C\r\nfolder_relative TEXT \x2C\r\ncreatestamp DATETIME \x2C \r\nmodifystamp DATETIME \x2C \r\npermissions INTEGER \x2C \r\ngroup_owner TEXT \x2C \r\nuser_owner TEXT \x2C \r\nisalias BOOLEAN NOT NULL \x2C \r\nisvisible BOOLEAN NOT NULL \x2C\r\nshellpath TEXT \x2C\r\nerror TEXT);", Scope = Private
	#tag EndConstant


	#tag Enum, Name = SurveyStates, Type = Integer, Flags = &h0
		Running
		  Completed
		  Killed
		  FatalError
		  Initialized
		Worker
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="Type"
			Visible=true
			Group="Behavior"
			InitialValue="0"
			Type="Types"
			EditorType="Enum"
			#tag EnumValues
				"0 - Cooperative"
				"1 - Preemptive"
			#tag EndEnumValues
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Priority"
			Visible=true
			Group="Behavior"
			InitialValue="5"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="StackSize"
			Visible=true
			Group="Behavior"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
