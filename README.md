In-game-debugging-tool
======================

In-game debugging tool for Monkey-X cross-translator.
This tool is very easy to attach to any game engine and it allows the developer
to drag & drop game objects and use dev-console for various things;
 - View object's fields, methods ...everything that's public
 - Set selected object's field values
 - Call object's methods with various input types. Currently supported; Int, Float, String, Bool and Arrays
 - View classes constants, fields, methods, globals, functions (if public) and super-class (if reflected)
 - Variable watch for objects (fields) and classes (globals)

Please be aware that this tool is under heavy development and it might not be stable - at all.
Use at your own risk!

Test It!
========
[HTML5 demo](http://misthema.anapnea.net/igdt/)


Requirements
============

In-game debugging tool requires the free FontMachine module to work.
You can get it [here](https://code.google.com/p/fontmachine/).

Also, to get the dev-console working properly, you're going to need to do [this fix](http://www.jungleide.com/?topic=gettextwidth/#post-5719).


Images
======

Search for methods and call them with input:
![Debugger in-action](http://puu.sh/aibkb/18155597ce.png)

Setting values into fields:

![Setting values into fields](http://puu.sh/akF58/2ebf433e63.png)

Adding properties to watch-list:

![Watch list testing](http://puu.sh/aoW5g/7224b9c747.png)


The code of the method called in the first picture:
```monkey
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
```



How-to
======

Basic implementation:
```monkey
#REFLECTION_FILTER="what.ever.you.need"

Import ingamedebugtool

...

'In your create method
DevConsole.Init()

...

'In your update method
DevConsole.Update()

...

'In you render method
DevConsole.Render()


'And you're done!
```


Adding fields and globals to watch:
```monkey
'Use these after initialization.

'These will be showed for selected (all) objects. (left side of the screen)
DevConsole.Watch(["fieldVar1", "fieldVar2", ..."fieldVarN"])

'These will be showed for selected (specific class) objects. (left side of the screen)
DevConsole.Watch(["fieldVar1", "fieldVar2", ..."fieldVarN"], "MyClass")

'These will be showed for classes. (right side of the screen)
DevConsole.GlobalWatch("ClassName", ["globalVar1", "globalVar2", ..."fieldVarN"])
```

And that's it!
