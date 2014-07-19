#REM
    In-game debugger tool for Monkey-X
    
    Copyright (C) 2014  V. Lehtinen a.k.a. misthema
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    E-mail: misthema@gmail.com
#END



Strict

Import "data/console/console.txt"
Import "data/console/console_P_1.png"


Import reflection
Import mojo.mojo
Import fontmachine

' Whether we are in debug mode or not.
' Not sure if this is smart or not...
#IF CONFIG="debug"
    Const DEBUG:Bool = True
#ELSE
    Const DEBUG:Bool = False
#END

Class InterfaceNotImplementedException Extends Throwable
    Field message:String
    
    Method New(obj:Object)
        Local cInfo:ClassInfo = GetClass(obj)
        message = "Trying to add '" + cInfo.Name() + "' object that hasn't implemented IDebuggable interface!"
    End Method
    
    Method ToString:String()
        Return message
    End Method
End Class


' This interface should be implemented to classes that work as game objects in engines
Interface IDebuggable
    ' Coordinates so debug tool is able to drag&drop objects
    Method X:Int() Property
    Method Y:Int() Property
    Method X:Void(val:Int) Property
    Method Y:Void(val:Int) Property

    ' This is used to check if mouse
    ' is over an object when clicked
    Method MouseOverMe:Bool()
    
    ' This is used to check if a
    ' selection area is over an object
    Method AreaOverMe:Bool(x:Int, y:Int, w:Int, h:Int)
    
    ' This is used to draw debug information
    ' over selected object(s)
    Method DebugOverlay:Void()
End Interface


' /////////////////////////////////////////////////
' //       The all-mighty DevConsole!!!
' /////////////////////////////////////////////////
Class DevConsole

    ' Console placement and size
    Global x:Int, y:Int, width:Int, height:Int
    
    ' Logging
    Global log:StringList, currentLine:Int, scroll:Int
    
    ' Are we active?
    Global active:Bool = False
    Global consoleOpen:Bool = False
    
    ' Whether you want to also print all messages to current output channel
    Global useDefaultPrint:Bool = False
    
    ' Selectable objects
    Global selectable:List<Object>
    
    Global consoleFont:BitmapFont
    Global fontHeight:Int, spacing:Int = 8
    
    
    ' Initialize console. Use Reset() if you need to re-initialize.
    Function Init:Void()
        If Not DEBUG Then Return ' <- And talking about smart, I meant this here.
        If _inited = True Then Return
        
        ' Default position and size
        x = 64
        y = 0
        width = DeviceWidth() -128
        height = DeviceHeight() / 2
        
        ' Load font
        consoleFont = New BitmapFont("console.txt", True)
        fontHeight = consoleFont.GetTxtHeight("X")
        
        ' Logging
        log = New StringList()
        currentLine = 0
        scroll = 0
        Log(" - Welcome to In-game Debugging Tool! - ")
        
        ' Watch list prints
        _textLines = New StringList()
        
        ' Selectable objects list
        selectable = New List<Object>()
        
        ' Selected objects list
        _selected = New List<Object>()
        
        ' Properties watch list
        _watchList = New StringList()
        
        ' Some properties to watch list
        Watch(["x", "y"])
        
        ' Init helps
        _helps = New StringList()
        _helps.AddLast("Select single object: [Shift] + Left Mouse ")
        _helps.AddLast("Select multiple objects: Hold Right Mouse")
        _helps.AddLast("Select all objects: Shift + A")
        _helps.AddLast("Drag&Drop (selected): Shift + Right Mouse")

        
        ' All done.
        _inited = True
    End Function
    
    
    ' Re-initialize console
    Function Reset:Void()
        If Not DEBUG Then Return
        _inited = False
        Init()
    End Function
    
    ' Enable or disable debug environment
    Function SetEnabled:Void(value:Bool = True)
        active = value
    End Function
    
    ' Disable debug environment
    Function Disable:Void()
        active = False
    End Function
    
    ' Enable debug environment
    Function Enable:Void()
        active = True
    End Function
    
    ' Returns TRUE if debug environment is enabled, FALSE if not
    Function Enabled:Bool()
        Return active
    End Function
    
    ' Open or close debug console
    Function SetConsoleOpen:Void(value:Bool = True)
        If active Then
            consoleOpen = value
        End If
    End Function
    
    ' Open console
    Function OpenConsole:Void()
        If active
            consoleOpen = True
        End If
    End Function
    
    ' Close console
    Function CloseConsole:Void()
        If active
            consoleOpen = False
        End If
    End Function
    
    ' Returns TRUE if console is open, FALSE if not
    Function ConsoleOpen:Bool()
        Return consoleOpen
    End Function
    
    
    ' Prints a message to console
    Function Log:Void(msg:String)
        If Not DEBUG Then Return
        log.AddFirst(msg)
        currentLine += 1
        
        ' Default printing
        If useDefaultPrint Then Print(msg)
        
    End Function
    
    Function Scroll:Void(val:Int)
        scroll += val
        If scroll < 0 Then scroll = 0
        If scroll > log.Count() -1 Then scroll = log.Count() -1
    End Function
    
    ' Add properties to watch list. Will be showed for selected object(s).
    Function Watch:Void(properties:String[])
        If Not DEBUG Then Return
        Local p:String
        
        If properties.Length() > 1
            For p = EachIn properties
                _watchList.AddLast(p)
            End For
        Else
            _watchList.AddLast(properties[0])
        End If
        
    End Function
    
    
    ' Set up custom mouse input (singleton with globals). If not set, Mojo's MouseX() and MouseY() will be used.
    Function SetupCustomMouseSingleton:Void(className:String, xyGlobals:String[])
        _customMouseClass = GetClass(className)
        
        If _customMouseClass = Null Then Error("Class '" + className + "' doesn't exist.")
        
        If xyGlobals.Length() = 0 Then Error("No fields set for custom mouse!")
        
        _customMouseGlobals = New GlobalInfo[xyGlobals.Length()]
        
        For Local i:= 0 Until xyGlobals.Length()
            _customMouseGlobals[i] = _customMouseClass.GetGlobal(xyGlobals[i])
        End For
    End Function
    
    ' Set up custom mouse input (object-instance with fields). If not set, Mojo's MouseX() and MouseY() will be used.
    Function SetupCustomMouseObject:Void(mouseObject:Object, xyFields:String[])
        _customMouseClass = GetClass(mouseObject)
        _customMouseObject = mouseObject
        
        If _customMouseClass = Null Then Error("Unable to find class for custom mouse object!")
        
        If xyFields.Length() = 0 Then Error("No fields set for custom mouse!")
        
        _customMouseFields = New FieldInfo[xyFields.Length()]
        
        For Local i:= 0 Until xyFields.Length()
            _customMouseFields[i] = _customMouseClass.GetField(xyFields[i])
        End For
        
        _customMouseClass = Null
    End Function
    
    ' Add object so it is selectable
    Function AddObject:Void(obj:Object)
        Try
            If IDebuggable(obj)
                selectable.AddLast(obj)
            Else
                Throw New InterfaceNotImplementedException(obj)
            End If
        Catch e:InterfaceNotImplementedException
            Error(e.ToString())
        End Try
    End Function
    
    ' Add object list so they are selectable
    Function AddObjects:Void(objList:List<Object>)
        For Local obj:= EachIn objList
            AddObject(obj)
        End For
    End Function
    
    ' Add objects array so they are selectable
    Function AddObjects:Void(objArr:Object[])
        For Local obj:= EachIn objArr
            AddObject(obj)
        End For
    End Function
    
    ' Select objects.
    ' If clear is FALSE, selection will be adding objects.
    ' If clear is TRUE, new single object will be selected.
    Function SelectObject:Void(clear:Bool = True)
        ' This, so we can do an adding selection
        If clear Then _selected.Clear()
        
        ' Add objects to list
        For Local obj:= EachIn selectable
        
            ' We don't want duplicates...
            If _selected.Contains(obj) Continue
        
            ' Add object    
            If IDebuggable(obj).MouseOverMe() Then
                _selected.AddLast(obj)
            End If
        End For
    End Function
    
    ' Select multiple objects inside an area.
    ' If clear is FALSE, selection will be adding objects.
    ' If clear is TRUE, new objects will be selected.
    Function SelectObjects:Void(x:Int, y:Int, w:Int, h:Int, clear:Bool = True)
        ' This, so we can do an adding selection
        If clear Then _selected.Clear()
        
        ' Add objects to list
        For Local obj:= EachIn selectable
        
            ' We don't want duplicates...
            If _selected.Contains(obj) Continue
        
            ' Add object
            If IDebuggable(obj).AreaOverMe(x, y, w, h) Then
                _selected.AddLast(obj)
            End If
        End For
    End Function
    
    ' Updates mouse handling, selecting and dragging
    Function UpdateSelecting:Void()
        
        ' Select object if mouse has been clicked
        If MouseHit()
            ' If user holds down SHIFT key,
            ' selection will add objects.
            ' Otherwise select new object.
            If KeyDown(KEY_SHIFT) Then
                SelectObject(False)
            Else
                SelectObject()
            End If
        End If
        
        If MouseHit(MOUSE_RIGHT)
            If KeyDown(KEY_SHIFT) Then
                _dragging = True
                _dragX = _MouseX()
                _dragY = _MouseY()
            Else
                _selecting = True
                _selX = _MouseX()
                _selY = _MouseY()
            End If
        End If
        
        If MouseDown(MOUSE_RIGHT)
            If _selecting Then
                _selW = _MouseX() -_selX
                _selH = _MouseY() -_selY
            End If
            
            If _dragging And _selected.Count() > 0 Then
                _deltaX = _MouseX() -_dragX
                _deltaY = _MouseY() -_dragY
            
                For Local obj:= EachIn _selected
                    IDebuggable(obj).X += _deltaX
                    IDebuggable(obj).Y += _deltaY
                End For
                
                _dragX = _MouseX()
                _dragY = _MouseY()
            End If
        Else
            If _dragging Then _dragging = False
            If _selecting Then
                _selecting = False
                
                ' If user holds down SHIFT key,
                ' selection will add objects.
                ' Otherwise select new objects.
                'If KeyDown(KEY_SHIFT) Then
                '    SelectObjects(_selX, _selY, _selW, _selH, False)
                'Else
                    SelectObjects(_selX, _selY, _selW, _selH)
                'End If
            End If
        End If
        
        If KeyDown(KEY_SHIFT)
            If KeyHit(KEY_A)
                Local selX:Int = _CameraX()
                Local selY:Int = _CameraY()
                Local selW:Int = _CameraX() +DeviceWidth()
                Local selH:Int = _CameraY() +DeviceHeight()
                
                SelectObjects(selX, selY, selW, selH)
            End If
        End If
        
        
    End Function
    
    ' Update the system
    Function Update:Void()
        
        'Nothing to update if not in DEBUG-mode
        If Not DEBUG Then Return
        
        If active Then
            
            ' Updates mouse handling and object selecting
            UpdateSelecting()
            
            ' Help toggling
            If KeyHit(KEY_H) And consoleOpen = False Then _showHelp = Not _showHelp
        
            ' We're clearing the text list on every cycle. Would be ugly if not!
            _textLines.Clear()
            
            ' Basic information
            _textLines.AddLast("Mouse: " + _MouseX() + ", " + _MouseY())
            
            
            ' See if there's any selected objects
            If _selected.Count() <> 0
            
                ' If the selected objects count is higher than one (1),
                ' we only show the selected amount.
                If _selected.Count() > 1
                    _textLines.AddLast("Selected: " + _selected.Count())
                    
                ' If not, we print the watched fields of one selected object
                Else
                    Local obj:Object = _selected.First() ' Our only selected object
                    Local cInfo:ClassInfo = GetClass(obj) ' Objects class
                    
                    ' Add texts
                    _textLines.AddLast("")
                    _textLines.AddLast("- " + cInfo.Name() + " -")
                    
                    
                    Local _field:FieldInfo
                    
                    ' Get each property from watch list and
                    ' unbox their values to printable format
                    For Local prop:= EachIn _watchList
                        _field = cInfo.GetField(prop)
                        
                        If _field <> Null
                            ' Field value is stored here
                            Local value:String
                            
                            ' Get the boxed field value from instance 'obj'
                            Local box:Object = _field.GetValue(obj)
                            
                            ' Unbox the value properly
                            Select _field.Type.Name()
                                Case "monkey.boxes.IntObject"
                                    value = UnboxInt(box)
                                    
                                Case "monkey.boxes.FloatObject"
                                    value = UnboxFloat(box)
                                    
                                Case "monkey.boxes.StringObject"
                                    value = UnboxInt(box)
                                    
                                Case "monkey.boxes.BoolObject"
                                    If UnboxBool(box) = True
                                        value = "True"
                                    Else
                                        value = "False"
                                    End If
                                    
                                ' If the value is unknown or null, set it to "N/A"
                                Default
                                    value = "N/A"
                            End Select
                            
                            ' Add the field name and value to list so we can print it later
                            _textLines.AddLast(prop + ": " + value)
                            
                        End If
                    End For
                End If
            End If
            
            If consoleOpen Then DevConsoleInput.Update()
         End If
        
    End Function
    
    Function Render:Void()
        'Nothing to render if not in DEBUG-mode
        If Not DEBUG Then Return
        
        If active Then
        
            ' If we're painting a selection area, draw it
            If _selecting Then DrawSelectionArea()
        
            ' Render selected objects debug overlays
            If _selected.Count() > 0
                For Local obj:= EachIn _selected
                    IDebuggable(obj).DebugOverlay()
                End For
            End If
            
            ' Show FPS
            SetColor(255, 255, 255)
            consoleFont.DrawText("FPS: " + _fps, 2, 0)
            
            ' Render the text information about selected objects (property watch)
            If _textLines.Count() > 0
            
                ' Current line rendering
                Local curLine:Int = 0
                
                ' Where to start rendering
                Local devH:Int = mojo.graphics.DeviceHeight()
                Local startHeight:Int = devH - (fontHeight * _textLines.Count() +4)
                
                ' Text position
                Local tY:Int
                
                ' Render texts
                For Local line:= EachIn _textLines
                    ' Calculate text position
                    tY = startHeight + curLine * fontHeight
                    
                    ' Draw text line
                    consoleFont.DrawText(line, 4, tY)
                    
                    ' Increment current line
                    curLine += 1
                End For
            End If
            
            ' Draw help-texts
            If _showHelp Then
                Local i:Int = 0
                For Local help:= EachIn _helps
                    consoleFont.DrawText(help, 2, fontHeight + fontHeight * i)
                    i += 1
                End For
            Else
                consoleFont.DrawText("[H]elp", 2, fontHeight)
            End If
            
            ' Draw console and log texts
            If consoleOpen Then DrawConsole()
            
        End If
        
        ' Update FPS
        If _fpsTimer < Millisecs() Then
            _fps = _renders
            _renders = 0
            _fpsTimer = Millisecs() +1000
        Else
            _renders += 1
        End If
    End Function
    
    ' Draws the area that is currently being selected
    Function DrawSelectionArea:Void()
        SetAlpha(0.3)
        SetColor(255, 255, 255)
        DrawRect(_selX, _selY, _selW, _selH) 'fill
        SetAlpha(1.0)
        DrawRectOutlined(_selX, _selY, _selW, _selH) 'borders
        
    End Function
    
    Function DrawRectOutlined:Void(x:Int, y:Int, w:Int, h:Int)
        DrawLine(x, y, x + w, y) 'top
        DrawLine(x, y + h, x + w, y + h) 'bot
        DrawLine(x, y, x, y + h) 'left
        DrawLine(x + w, y, x + w, y + h) 'right
    End Function
    
    Function DrawConsole:Void()
        ' Draw console layout
        SetAlpha(0.4)
        SetColor(64, 96, 160)
        DrawRect(x, y, width, height) 'fill
        SetAlpha(0.8)
        DrawRectOutlined(x, y, width, height) 'borders
        
        ' Inits
        Local startY:Int = height - fontHeight * 2
        Local tY:Int
        
        SetAlpha(0.2)
        DrawRect(x, height - fontHeight, width, fontHeight)
        DrawRectOutlined(x, height - fontHeight, width, fontHeight) 'borders
        
        ' Scroll bar (vertical)
        DrawScrollBar(x + width - 16, y, 16, height - fontHeight)
        
        SetAlpha(1.0)
        SetColor(255, 255, 255)
        
        Local i:Int = 0
        _tempTexts = log.ToArray()[scroll .. log.Count()]
        
        ' Draw log texts
        For Local msg:= EachIn _tempTexts
            tY = startY - i * fontHeight
            consoleFont.DrawText(msg, x + 1, tY)
            i += 1
        End For
        
        _tempTexts =[]
        
        DevConsoleInput.Draw(x + 1, height - fontHeight)
        
    End Function
    
    ' Scroll bar
    Function DrawScrollBar:Void(x:Int, y:Int, w:Int, h:Int, hor:Bool = False)
        Local arrowSize:Int = 8
        ' View port size
        Local vPortSize:Int
        ' Content height
        Local contentSize:Int
        ' Thumb size
        Local thumbSize:Int
        ' Viewable ratio
        Local vRatio:Float
        ' Scrollable area
        Local scrollBarArea:Int
        
        SetAlpha(0.1)
        SetColor(128, 160, 255)
        DrawRect(x, y, w, h) 'base fill
        If hor Then
            'HMMH
        Else
            SetAlpha(0.2)
            DrawRect(x, y, w, arrowSize) 'top arrow
            DrawRect(x, y + h - arrowSize, w, arrowSize) 'bot arrow
            
            SetAlpha(0.5)
            
            ' Please do not questionalize this... It was really terrible to make :-D
            vPortSize = h
            contentSize = log.Count() * fontHeight
            vRatio = vPortSize / contentSize
            scrollBarArea = vPortSize - arrowSize * 2
            thumbSize = Min(scrollBarArea, Max(Int(scrollBarArea * vRatio), 8))
            
            DrawRect(x, (y + scrollBarArea + arrowSize) - thumbSize * (scroll + 1), w, thumbSize) 'scroll-thumb
        End If
    End Function
    
    Function SelectedObjects:List<Object>()
        Return _selected
    End Function
    
    ' /////////////////////////////////////////////
    ' Private functions
    Private
        Function _MouseX:Int()
            If _customMouseClass <> Null
                Return _CameraX() +UnboxInt(_customMouseGlobals[_CUSTOM_MOUSE_X].GetValue())
            Else If _customMouseObject <> Null
                Return _CameraX() +UnboxInt(_customMouseFields[_CUSTOM_MOUSE_X].GetValue(_customMouseObject))
            End If
            
            Return MouseX()
        End Function
        
        Function _MouseY:Int()
            If _customMouseClass <> Null
                Return _CameraY() +UnboxInt(_customMouseGlobals[_CUSTOM_MOUSE_Y].GetValue())
            Else If _customMouseObject <> Null
                Return _CameraY() +UnboxInt(_customMouseFields[_CUSTOM_MOUSE_Y].GetValue(_customMouseObject))
            End If
        
            Return MouseY()
        End Function
        
        Function _CameraX:Int()
            If _customCameraClass <> Null
                Return UnboxInt(_customCameraGlobals[_CUSTOM_CAMERA_X].GetValue())
            Else If _customMouseObject <> Null
                Return UnboxInt(_customCameraFields[_CUSTOM_CAMERA_X].GetValue(_customCameraObject))
            End If
                
            Return 0
        End Function
            
        Function _CameraY:Int()
            If _customCameraClass <> Null
                Return UnboxInt(_customCameraGlobals[_CUSTOM_CAMERA_Y].GetValue())
            Else If _customMouseObject <> Null
                Return UnboxInt(_customCameraFields[_CUSTOM_CAMERA_Y].GetValue(_customCameraObject))
            End If
            
            Return 0
        End Function
    
        ' /////////////////////////////////////////////
        ' Private variables
    
        Global _fps:Int, _fpsTimer:Int, _renders:Int
        
        Global _inited:Bool = False
        Global _watchList:StringList
        Global _selected:List<Object>
        Global _textLines:StringList, _tempTexts:String[]
        Global _dragging:Bool = False
        Global _dragX:Int, _dragY:Int, _deltaX:Int, _deltaY:Int
        Global _selecting:Bool = False
        Global _selX:Int, _selY:Int, _selW:Int, _selH:Int
        
        ' Custom mouse class and globals (Singleton)
        Global _customMouseClass:ClassInfo, _customMouseGlobals:GlobalInfo[]
        
        ' Custom mouse object and fields (Instance)
        Global _customMouseObject:Object, _customMouseFields:FieldInfo[]
        Const _CUSTOM_MOUSE_X:Int = 0
        Const _CUSTOM_MOUSE_Y:Int = 1
        
        ' Custom camera class and globals (Singleton)
        Global _customCameraClass:ClassInfo, _customCameraGlobals:GlobalInfo[]
        
        ' Custom camera object and fields (Instance)
        Global _customCameraObject:Object, _customCameraFields:FieldInfo[]
        Const _CUSTOM_CAMERA_X:Int = 0
        Const _CUSTOM_CAMERA_Y:Int = 1
        
        
        ' StringList for help-texts
        Global _helps:StringList
        Global _showHelp:Bool = False
        
End Class


Class DevConsoleInput
    Global text:String, chars:= New Stack<Int>(), char:Int, cursorPos:Int, cursorBlink:Bool = False, blinkTimer:Float = 0
    Global oldTexts:String[] = New String[1], currentOld:Int
    Global tempInputTypes:ClassInfo[] =[]
    
    Function Draw:Void(x:Float, y:Float)
        ' Draw text
        DevConsole.consoleFont.DrawText("> " + text, x, y)
        
        ' Show cursor
        If cursorBlink
            ' For some reason this cursor goes a little bit off after few letters...
            Local curPos:Int = DevConsole.consoleFont.GetTxtWidth("> " + text[0 .. cursorPos]) - (DevConsole.consoleFont.GetTxtWidth("|")/2)
            DevConsole.consoleFont.DrawText("|", x + curPos, y)
        End
    End
    
    Function Update:Void()
        char = GetChar()
        
        Select char
            Case CHAR_TAB
            Case CHAR_BACKSPACE
                If text.Length() > 0
                    If cursorPos < text.Length()
                        text = text[ .. cursorPos - 1] + text[cursorPos ..]
                    Else
                        text = text[0 .. text.Length() -1]
                    EndIf
                    
                    cursorPos -= 1
                End
            Case CHAR_ENTER
                oldTexts = oldTexts.Resize(oldTexts.Length() +1)
                oldTexts[oldTexts.Length() -1] = text
                ProcessInput(text) ' Process our input
                text = ""
                currentOld = oldTexts.Length()
            Case CHAR_PAGEUP
                DevConsole.Scroll(1)
            Case CHAR_PAGEDOWN
                DevConsole.Scroll(-1)
            Case CHAR_END
                cursorPos = text.Length()
            Case CHAR_HOME
                cursorPos = 0
            Case CHAR_LEFT
                cursorPos -= 1
                If cursorPos < 0 cursorPos = 0
            Case CHAR_UP
                Old(-1)
            Case CHAR_RIGHT
                cursorPos += 1
                If cursorPos > text.Length() cursorPos = text.Length()
            Case CHAR_DOWN
                Old(1)
            Case CHAR_INSERT
                text = text[ .. cursorPos] + " " + text[cursorPos ..]
            Case CHAR_DELETE
                text = text[ .. cursorPos] + text[cursorPos + 1 ..]
            Default
                If char >= 32
                    text += String.FromChar(char)
                    cursorPos += 1
                End
        End
        
        If blinkTimer < Millisecs()
            cursorBlink = Not cursorBlink
            blinkTimer = Millisecs() +500
        End
    End
    
    Private
    Function Old:Void(dir:Int)
        If currentOld < 0 currentOld = oldTexts.Length() -1
        If currentOld >= oldTexts.Length() currentOld = 0
        text = oldTexts[currentOld]
        currentOld -= dir
        cursorPos = text.Length()
    End
    
    
    
    '///////////////////////////////////////////////////////////////////
    '// Input processing
    '
    Function ProcessInput:Void(input:String)
        Local args:String[] = input.Split(" ")
        Local argsLen:Int = args.Length()
        
        ' Print the input with "> " prefix so it's more easily spotted.
        DevConsole.Log("> " + input)
        
        
        ' Oh, empty string? Well that's sad.
        If args.Length() = 0 Then Return
        
        
        ' Select the command
        Select args[0].ToLower()
            Case "get_obj"
            
                ' No idea why but lets get all of them.
                Local objs:List<Object> = DevConsole.SelectedObjects()
                
                If objs.Count() > 0
                    ' But we still use one of them.
                    Local obj:Object = objs.First()
                
                    If argsLen = 2
                        Command_Obj_Get([args[1], ""], obj)
                        
                    Else If argsLen = 3
                        Command_Obj_Get(args[1 .. 3], obj)
            
                    Else
                        ' Print help for "get_obj"
                        Help_Command_Get_Obj()
                    End If
                Else
                    DevConsole.Log("Nothing to get; no object selected.")
                End If
                
            Case "get_class"
                
                If argsLen = 3
                    Command_Class_Get(args[1], args[2])
                Else If argsLen = 1
                    PrintAllClasses()
                Else
                    Help_Command_Get_Class()
                End If
                
                
            Case "set_obj"
                Local objs:List<Object> = DevConsole.SelectedObjects()
                
                If objs.Count() > 0
                    ' But we still use one of them.
                    Local obj:Object = objs.First()
                    
                    If argsLen = 3
                        Command_Obj_Set(obj, args[1], args[2])
                    End If
                    
                Else
                    DevConsole.Log("Nothing to set; no object selected.")
                End If
                
            Case "set_class"
            
            
            Case "call_obj"
                Local objs:List<Object> = DevConsole.SelectedObjects()
                
                If objs.Count() > 0
                    ' But we still use one of them.
                    Local obj:Object = objs.First()
                    
                    If argsLen > 2
                        input = input.Replace(args[0], "").Replace(args[1], "").Trim()
                        Command_Obj_Call(obj, args[1], input)
                    Else If argsLen = 2
                        Command_Obj_Call(obj, args[1], "")
                    Else
                        DevConsole.Log("Invalid format. Should be 'call_obj <method> <param1>, <param2>, ..<paramN>")
                    End If
                    
                Else
                    DevConsole.Log("Nothing to call; no object selected.")
                End If
        End
    End
    
    
    
    
    '///////////////////////////////////////////////////////////////////
    '// Object fetch's
    '
    Function Obj_FetchFields:Void(obj:Object, arg:String)
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:FieldInfo
        Local value:String
        
        If arg <> "" Then
            DevConsole.Log("Field:")
            fInfo = cInfo.GetField(arg)
            value = GetValue(fInfo, obj)
            DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type) + " = " + value)
        Else
            DevConsole.Log("Fields:")
            For fInfo = EachIn cInfo.GetFields(True)
                DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type))
            End For
        End If
    End Function
    
    Function Obj_FetchGlobals:Void(obj:Object, arg:String)
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:GlobalInfo
        Local value:String
        
        If arg <> "" Then
            DevConsole.Log("Field:")
            fInfo = cInfo.GetGlobal(arg)
            value = GetValue(fInfo, obj)
            DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type) + " = " + value)
        Else
            DevConsole.Log("Globals:")
            For fInfo = EachIn cInfo.GetGlobals(True)
                DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type))
            End For
        End If
    End Function
    
    Function Obj_FetchConstants:Void(obj:Object, arg:String)
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:ConstInfo
        Local value:String
        
        If arg <> "" Then
            DevConsole.Log("Field:")
            fInfo = cInfo.GetConst(arg)
            value = GetValue(fInfo, obj)
            DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type) + " = " + value)
        Else
            DevConsole.Log("Constants:")
            For fInfo = EachIn cInfo.GetConsts(True)
                DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type))
            End For
        End If
    End Function
    
    Function Obj_FetchMethods:Void(obj:Object, arg:String)
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:MethodInfo
        Local params:String

        DevConsole.Log("Methods:")
        For fInfo = EachIn cInfo.GetMethods(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + FetchReturnType(fInfo) + "(" + ParseParameters(fInfo.ParameterTypes()) + ")")
        End For
    End Function
    
    Function Obj_FetchFunctions:Void(obj:Object, arg:String)
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:FunctionInfo
        
        DevConsole.Log("Functions:")
        For fInfo = EachIn cInfo.GetFunctions(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + FetchReturnType(fInfo) + "(" + ParseParameters(fInfo.ParameterTypes()) + ")")
        End For
    End Function
    
    Function Obj_FetchSuper:Void(obj:Object)
        Local cInfo:ClassInfo = GetClass(obj)
        Local iInfo:ClassInfo
        
        DevConsole.Log("Super class '" + cInfo.SuperClass().Name + "'")
        DevConsole.Log("Implements:")
        For iInfo = EachIn cInfo.Interfaces()
            DevConsole.Log("  " + iInfo.Name())
        End For
    End Function
    
    
    
    
    '///////////////////////////////////////////////////////////////////
    '// Class fetch's
    '
    Function Class_FetchFields:Void(className:String)
        Local cInfo:ClassInfo = GetClass(className)
        Local fInfo:FieldInfo
        
        If cInfo = Null Then
            DevConsole.Log("'" + className + "' doesn't exist.")
            Return
        End If
        
        DevConsole.Log("Fields:")
        For fInfo = EachIn cInfo.GetFields(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type))
        End For
    End Function
    
    Function Class_FetchGlobals:Void(className:String)
        Local cInfo:ClassInfo = GetClass(className)
        Local fInfo:GlobalInfo
        
        If cInfo = Null Then
            DevConsole.Log("'" + className + "' doesn't exist.")
            Return
        End If
        
        DevConsole.Log("Globals:")
        For fInfo = EachIn cInfo.GetGlobals(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type))
        End For
    End Function
    
    Function Class_FetchConstants:Void(className:String)
        Local cInfo:ClassInfo = GetClass(className)
        Local fInfo:ConstInfo
        
        If cInfo = Null Then
            DevConsole.Log("'" + className + "' doesn't exist.")
            Return
        End If
        
        DevConsole.Log("Constants:")
        For fInfo = EachIn cInfo.GetConsts(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + ParseTypeName(fInfo.Type))
        End For
    End Function
    
    Function Class_FetchMethods:Void(className:String)
        Local cInfo:ClassInfo = GetClass(className)
        Local fInfo:MethodInfo
        Local params:String
        
        If cInfo = Null Then
            DevConsole.Log("'" + className + "' doesn't exist.")
            Return
        End If
        
        
        DevConsole.Log("Methods:")
        For fInfo = EachIn cInfo.GetMethods(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + FetchReturnType(fInfo) + "(" + ParseParameters(fInfo.ParameterTypes()) + ")")
        End For
    End Function
    
    Function Class_FetchFunctions:Void(className:String)
        Local cInfo:ClassInfo = GetClass(className)
        Local fInfo:FunctionInfo
        
        If cInfo = Null Then
            DevConsole.Log("'" + className + "' doesn't exist.")
            Return
        End If
        
        DevConsole.Log("Functions:")
        For fInfo = EachIn cInfo.GetFunctions(True)
            DevConsole.Log("  " + fInfo.Name() + ":" + FetchReturnType(fInfo) + "(" + ParseParameters(fInfo.ParameterTypes()) + ")")
        End For
    End Function
    
    Function Class_FetchSuper:Void(className:String)
        Local cInfo:ClassInfo = GetClass(className)
        Local iInfo:ClassInfo
        
        If cInfo = Null Then
            DevConsole.Log("'" + className + "' doesn't exist.")
            Return
        End If
        
        DevConsole.Log("Super class '" + cInfo.SuperClass().Name + "'")
        DevConsole.Log("Implements:")
        For iInfo = EachIn cInfo.Interfaces()
            DevConsole.Log("  " + iInfo.Name())
        End For
    End Function
    
    
    
    '///////////////////////////////////////////////////////////////////
    '// Parsers
    '
    Function ParseInput:String[] (input:String)
        Local parsed:String[10], current:Int = 0
        Local char:String
        tempInputTypes = New ClassInfo[10]
        
        For Local i:= 0 Until input.Length()
        
            char = String.FromChar(input[i])
            
            ' We're reading a number
            If char = "." or isdigit(char) Then
                parsed[current] = ReadNumber(input, i)
                If parsed[current].Contains(".") Then
                    tempInputTypes[current] = FloatClass()
                Else
                    tempInputTypes[current] = IntClass()
                End If
                
                ' Add the length of the parsed text
                ' so we can get out of here faster.
                i += parsed[current].Length()
                current += 1
            
            ' We're reading a string
            Else If char = "~q" Then
                parsed[current] = ReadString(input, i)
                tempInputTypes[current] = StringClass()
                
                i += parsed[current].Length()
                current += 1
            
            ' We're reading a bool
            Else If char.ToLower() = "t" or char.ToLower() = "f" Then
                parsed[current] = ReadBool(input, i)
                tempInputTypes[current] = BoolClass()
                
                i += parsed[current].Length()
                current += 1
            End If
            
            
        End For
        
        ' Resize array so there's no empty cells
        If current > 0 Then
            parsed = parsed.Resize(current - 1)
            tempInputTypes = tempInputTypes.Resize(current - 1)
        Else
            Return[]
        End If
        
        Return parsed
    End Function
    
    Function ReadString:String(input:String, start:Int)
        Local char:String
        Local output:String = String.FromChar(input[start])
        
        start += 1 'So we don't break while loop with the first quote
        
        While char <> "~q" And start < input.Length()
            char = String.FromChar(input[start])
            
            output += char
            
            start += 1
        End While
        
        ' Remove any quotes or leading/trailing spaces
        Return output.Replace("~q", "").Trim()
    End Function
    
    Function ReadNumber:String(input:String, start:Int)
        Local char:String
        Local output:String = String.FromChar(input[start])
        
        start += 1
        
        While char <> "," And start < input.Length()
            char = String.FromChar(input[start])
            
            If isdigit(char) or char = "."
                output += char
            Else
                Exit
            End If
        
            start += 1
        End While
        
        Return output.Trim()
    End Function
    
    Function ReadBool:String(input:String, start:Int)
        Local char:String
        Local output:String = String.FromChar(input[start])
        
        start += 1
        
        While char <> "," And start < input.Length()
            char = String.FromChar(input[start])
            
            If char <> "," Then output += char
            
            start += 1
        End While
        
        
        If output.ToLower() = "true" or output.ToLower() = "false" Then
            Return output
        Else
            Return "false"
        End If
    End Function
    
    Function GuessInputTypes:ClassInfo[] (input:String[])
        If input.Length() = 0 Then Return[]
        
        Local types:= New ClassInfo[input.Length()]
        Local param:String
        
        For Local i:= 0 Until input.Length()
            param = input[i]
            
            If param = "" Then Continue
            
            If isalpha(param[0]) Then
                types[i] = StringClass()
            Else If isdigit(param[0]) Then
                If param.Contains(".") Then
                    types[i] = FloatClass()
                Else
                    types[i] = IntClass()
                End If
            Else If param.ToLower() = "true" or param.ToLower() = "false"
                types[i] = BoolClass()
            End If
        End For
        
        Return types
    End Function
    
    
    Function Asc:Int(char:String)
        Return char.ToChars()[0]
    End Function
    
    Function isdigit:Bool(ch:String)
        Return Asc(ch) >= Asc("0") And Asc(ch) <= Asc("9")
    End Function

    Function isalpha:Bool(ch:String)
        Return Asc(ch) = Asc("_") Or (Asc(ch) >= Asc("a") And Asc(ch) <= Asc("z")) Or (Asc(ch) >= Asc("A") And Asc(ch) <= Asc("Z"))
    End Function

    Function isxdigit:Bool(ch:Int)
        Return ( (Asc(ch) >= Asc("0") And Asc(ch) <= Asc("9")) Or (Asc(ch) >= Asc("a") And Asc(ch) <= Asc("f")) Or (Asc(ch) >= Asc("A") And Asc(ch) <= Asc("F")))
    End Function
    
    Function GetValue:String(info:Object, obj:Object)
        If info <> Null
            If FieldInfo(info) Then
                Local f:FieldInfo = FieldInfo(info)
                Return ParseValue(f.GetValue(obj), f.Type)
            Else If GlobalInfo(info)
                Local g:GlobalInfo = GlobalInfo(info)
                Return ParseValue(g.GetValue(), g.Type)
            Else If ConstInfo(info)
                Local c:ConstInfo = ConstInfo(info)
                Return ParseValue(c.GetValue(), c.Type)
            End If
        End If
        
        Return "<N/A>"
    End Function
    
    Function ParseValue:String(in:Object, type:ClassInfo)
        Select type.Name
            Case "monkey.boxes.IntObject"
                Return String(UnboxInt(in))
            Case "monkey.boxes.FloatObject"
                Return String(UnboxFloat(in))
            Case "monkey.boxes.BoolObject"
                If UnboxBool(in) = True
                    Return "True"
                Else
                    Return "False"
                End If
            Case "monkey.boxes.StringObject"
                Return UnboxString(in)
            Default
                Return "<Unknown>"
        End Select
        
        Return "<N/A>"
    End Function
    
    Function BoxValue:Object(in:String, type:ClassInfo)
        Select type.Name
            Case "monkey.boxes.IntObject"
                Return BoxInt(Int(in))
            Case "monkey.boxes.FloatObject"
                Return BoxFloat(Float(in))
            Case "monkey.boxes.BoolObject"
                If in.ToLower() = "true" or in = "1"
                    Return BoxBool(True)
                Else
                    Return BoxBool(False)
                End If
            Case "monkey.boxes.StringObject"
                Return BoxString(in)
            Default
                Return Null
        End Select
        
        Return Null
    End Function
    
    Function BuildMethodInput:Object[] (input:String[], types:ClassInfo[])
        If input.Length() = 0 Then Return[]
        
        Local rtn:= New Object[types.Length()]
        
        ' Invalid input
        If input.Length() <> types.Length() Then
            DevConsole.Log("Invalid input. Method takes " + types.Length() + " parameters (had " + input.Length() + ").")
        End If
        
        For Local i:= 0 Until types.Length()
            rtn[i] = BoxValue(input[i], types[i])
            
            ' Something went wrong
            If rtn[i] = Null Then
                DevConsole.Log("Something went wrong. Unable to build input for method.")
                Return[]
            End If
        End For
        
        Return rtn
    End Function
    
    Function ParseTypeName:String(c:ClassInfo)
        Select c.Name
            Case "monkey.boxes.IntObject"
                Return "Int"
            Case "monkey.boxes.FloatObject"
                Return "Float"
            Case "monkey.boxes.BoolObject"
                Return "Bool"
            Case "monkey.boxes.StringObject"
                Return "String"
            Default
                Return c.Name
        End Select
        
        Return "Void"
    End Function
    
    Function ParseParameters:String(params:ClassInfo[])
        Local rtn:String, add:String
        
        For Local c:ClassInfo = EachIn params
            add = ParseTypeName(c)
            
            rtn += add + ", "
        End For
        
        Return rtn[ .. rtn.Length() -2]
    End Function

    Function FetchReturnType:String(info:Object)
        If info <> Null
            If MethodInfo(info)
                If MethodInfo(info).ReturnType <> Null
                    Return ParseTypeName(MethodInfo(info).ReturnType)
                End If
            Else If FunctionInfo(info)
                If FunctionInfo(info).ReturnType <> Null
                    Return ParseTypeName(FunctionInfo(info).ReturnType)
                End If
            End If
        End If
        
        Return "Void"
    End Function
    
    
    
    '///////////////////////////////////////////////////////////////////
    '// Commands
    '
    Function Command_Obj_Get:Void(args:String[], obj:Object)
        Select args[0].ToLower()
            Case "field"
                Obj_FetchFields(obj, args[1])
            Case "global"
                Obj_FetchGlobals(obj, args[1])
            Case "const", "constant"
                Obj_FetchConstants(obj, args[1])
            Case "method"
                Obj_FetchMethods(obj, args[1])
            Case "function", "func"
                Obj_FetchFunctions(obj, args[1])
            Case "super"
                Obj_FetchSuper(obj)
            Case "all"
                Obj_FetchFields(obj, "")
                Obj_FetchGlobals(obj, "")
                Obj_FetchConstants(obj, "")
                Obj_FetchMethods(obj, "")
                Obj_FetchFunctions(obj, "")
                Obj_FetchSuper(obj)
                
            
                                
            Default
                Help_Command_Get_Obj()
        End Select
    End Function
    
    Function Command_Class_Get:Void(from:String, arg:String)
        Select arg.ToLower()
            Case "fields"
                Class_FetchFields(from)
            Case "globals"
                Class_FetchGlobals(from)
            Case "consts", "constants"
                Class_FetchConstants(from)
            Case "methods"
                Class_FetchMethods(from)
            Case "functions", "funcs"
                Class_FetchFunctions(from)
            Case "super"
                Class_FetchSuper(from)
            Case "all"
                Class_FetchFields(from)
                Class_FetchGlobals(from)
                Class_FetchConstants(from)
                Class_FetchMethods(from)
                Class_FetchFunctions(from)
                Class_FetchSuper(from)
                                
            Default
                Help_Command_Get_Class()
        End Select
    End Function
    
    
    Function Command_Obj_Set:Void(obj:Object, fieldName:String, value:String)
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:FieldInfo = cInfo.GetField(fieldName)
        
        If fInfo <> Null Then
            Local boxValue:Object = BoxValue(value, fInfo.Type)
            If boxValue <> Null Then
                fInfo.SetValue(obj, boxValue)
            Else
                DevConsole.Log("Failed to set value. Field type is " + ParseTypeName(fInfo.Type) + ".")
            End If
        End If
        
    End Function
    
    Function Command_Obj_Call:Void(obj:Object, methodName:String, input:String)
        Local parsedInput:String[] = ParseInput(input)
        Local inputTypes:ClassInfo[] = tempInputTypes 'GuessInputTypes(parsedInput)
        
        Local cInfo:ClassInfo = GetClass(obj)
        Local fInfo:MethodInfo = cInfo.GetMethod(methodName, inputTypes)
        Local output:Object, args:Object[]
        
        If fInfo <> Null Then
            args = BuildMethodInput(parsedInput, fInfo.ParameterTypes)
        
            If args.Length > 0
                output = fInfo.Invoke(obj, args)
            
                If output <> Null
                    DevConsole.Log("Method output: " + ParseValue(output, fInfo.ReturnType))
                Else
                    DevConsole.Log("Method has no output.")
                End If
            End If
        Else
            DevConsole.Log("Method '" + methodName + "' not found.")
        End If
        
    End Function


    ' A little helpfull function by programmer
    Function PrintAllClasses:Void()
        DevConsole.Log("Classes:")
        For Local clazz:= EachIn GetClasses()
            If clazz.Name.Contains("monkey") or clazz.Name.Contains("lang") Then Continue
            DevConsole.Log(clazz.Name)
        Next
    End Function
    
    
    
    '///////////////////////////////////////////////////////////////////
    '// Help texts
    '
    Function Help_Command_Get_Obj:Void()
        DevConsole.Log("Usage: get_obj <what> [name]")
        DevConsole.Log("Available <what>s:")
        DevConsole.Log("  field, global, const, method, func, super, all")
        DevConsole.Log("If [name] is not used, all fields/globals etc will be printed.")
    End Function
    
    Function Help_Command_Get_Class:Void()
        DevConsole.Log("Usage: get_class <ClassName> <what>")
        DevConsole.Log("Available <what>s:")
        DevConsole.Log("  fields, globals, constants, methods, functions, super, all")
    End Function
    
End Class