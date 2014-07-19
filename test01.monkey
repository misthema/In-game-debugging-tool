Strict

'#REFLECTION_FILTER="*"  'reflect everything!
#REFLECTION_FILTER="test01"

'Import reflection
Import mojo
Import ingamedebugtool

Function Main:Int()
	New Game()
	Return 0
End

Class Color
    Field r:Int, g:Int, b:Int
    
    Method New(r:Int, g:Int, b:Int)
        Self.r = r
        Self.g = g
        Self.b = b
    End Method
End Class

Class TestObject Implements IDebuggable
    Field x:Int, y:Int, width:Int, height:Int
    Field xVel:Int, yVel:Int
    Field color:Color
    
    Function TestFunction:String(input:String)
        Return "I am a function! Input was: " + input
    End Function
    
    Global testGlobal:Bool
    
    Method New()
        x = Rnd() * DeviceWidth()
        y = Rnd() * DeviceHeight()
        width = Rnd() * 100
        height = Rnd() * 100
        xVel = 1
        yVel = 1
        
        color = New Color(Rnd() * 255, Rnd() * 255, Rnd() * 255)
    End Method
    
    ' These properties are needed by the debugging tool system for drag&drop.
    Method X:Int() Property Return x End
    Method Y:Int() Property Return y End
    Method X:Void(val:Int) Property x = val End
    Method Y:Void(val:Int) Property y = val End
    
    Method TestMethod:String(input:String)
        Return "I am a Method! Input was: " + input
    End Method
    
    Method TestArray:String[] ()
        Return["Hello", "World!"]
    End Method
    
    Method TestStringArray:String(arrStr:String[])
        Local rtn:String = "Elements in array: "
        
        If arrStr.Length() > 0 Then
            rtn += arrStr.Length()
        Else
            rtn += "0 :("
        End If
        
        DevConsole.Log("DEBUG::Elements:",[128, 64, 64])
        For Local i:= 0 Until arrStr.Length()
            DevConsole.Log("  - " + arrStr[i])
        End For
        
        Return "~q" + rtn + "~q"
    End Method
    
    Method TestMethod2:String(i:Int, f:Float, b:Bool, s:String)
        Local _bool:String
        If b Then _bool = "True" Else _bool = "False"
        Return "I am a Method2! Input was: " + i + ", " + f + ", " + _bool + ", " + s
    End Method
    
    Method OnRender:Void()
        SetColor(color.r, color.g, color.b)
        DrawRect(x, y, width, height)
    End Method
    
    Method OnUpdate:Void()
        ' Apply velocities
        x += xVel
        y += yVel
        
        ' Don't let the boxes escape!
        If x < - width x = DeviceWidth()
        If y < - height y = DeviceHeight()
        If x > DeviceWidth() x = -width
        If y > DeviceHeight() y = -height
    End Method

    ' Very basic implementation. Returns TRUE if mouse hits the object
    Method MouseOverMe:Bool()
        If MouseX() > x And MouseX() < x + width And MouseY() > y And MouseY() < y + height
            Return True
        End If
        Return False
    End Method
    
    ' Very basic implementation. Returns TRUE if object "hits" the selection area
    Method AreaOverMe:Bool(x:Int, y:Int, w:Int, h:Int)
        If (x + w >= Self.x) And
            (y + h >= Self.y) And
            (x < Self.x + width) And
            (y < Self.y + height) Then
            Return True
        EndIf
		
        Return False
    End Method
    
    ' Here you could draw your object's hitbox etc
    Method DebugOverlay:Void()
        SetColor(255, 255, 255)
        DrawLine(x, y, x + width, y) 'top
        DrawLine(x, y + height, x + width, y + height) 'bot
        DrawLine(x, y, x, y + height) 'left
        DrawLine(x + width, y, x + width, y + height) 'right
    End Method
End Class

' Just a test class to show-off the custom mouse system
Class CustomMouseClass
    Global mx:Int, my:Int
    
    Function Update:Void()
        mx = MouseX() +32
        my = MouseY() +32
    End Function
End Class


Class Game Extends App

    Field objectList:List<Object>

	Method OnCreate:Int()
		SetUpdateRate(60)
		
        objectList = New List<Object>
        
        For Local i:= 0 To 9
            objectList.AddLast(New TestObject())
        End For
        
        
        DevConsole.Init()
        DevConsole.AddObjects(objectList)
        
        DevConsole.Watch(["xVel", "yVel"])
        DevConsole.GlobalWatch("TestObject",["testGlobal"])
        DevConsole.GlobalWatch("CustomMouseClass",["mx","my"])
        
        ' Un-comment the line below to set up custom mouse. This mouse will be +32,+32px off ;)
        'DevConsole.SetupCustomMouseSingleton("CustomMouseClass",["mx", "my"])
			
		Return 0
	End
	
	Method OnUpdate:Int()
    
        'Update custom mouse
        CustomMouseClass.Update()

        For Local obj:= EachIn objectList
            TestObject(obj).OnUpdate()
        End For
        
        DevConsole.Update()
        
        Local k:Int = GetChar()
        If KeyHit(KEY_TAB) Then DevConsole.SetEnabled( Not DevConsole.Enabled())
        If KeyHit(KEY_TILDE) or k = 167 Then DevConsole.SetConsoleOpen( Not DevConsole.ConsoleOpen())
        
        If KeyDown(KEY_SPACE) Then
            TestObject.testGlobal = True
        Else
            TestObject.testGlobal = False
        End If
    
		Return 0
	End
	
	Method OnRender:Int()
		Cls()
        
        For Local obj:= EachIn objectList
            TestObject(obj).OnRender()
        End For
        
        DevConsole.Render()
		
		Return 0
	End

End