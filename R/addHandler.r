# Manually trigger shiny events when some value changes
# While this is also the key idea of reactive programming
# Shiny (at least in current versions as of October 2014)
# tends to trigger events too often.

# What we need:
#   1. Call a function or render output when a button is clicked
#   2. Call a function or render output when an input value has changed
#   3. Update input values when an input value or variable has changed without triggering further events


# Adds classic shiny handlers to session
addHandlersToSession = function(session.env=app$session.env, app=getApp()) {
  restore.point("addHandlersToSession")
  for (i in seq_along(app$handlers)) {
    app$handlers[[i]]$call.env = initHandlerCallEnv(app$handlers[[i]]$call.env, session.env)
    app$handlers[[i]]$observer = eval(app$handlers[[i]]$call,app$handlers[[i]]$call.env)
    #app$handlers[[i]]$observer = eval(app$handlers[[i]]$call, session.env)
  }
}

initHandlerCallEnv = function(call.env=NULL,session.env=app$session.env, app=getApp()) {
  if (is.null(call.env)) {
    call.env = session.env
  } else {
    parent.env(call.env) = session.env
  }
  call.env
}

destroyHandlerObserver = function(ind, app = getApp()) {
  if (app$is.running) {
    for (i in ind) {
      type = app$handlers[[i]]$type
      if (is.function(app$handlers[[i]]$observer))
        try(app$handlers[[i]]$observer$destroy())
    }
  }
}

removeEventHandler = function(id=NULL, ind=NULL, eventId=NULL, app = getApp()) {
  restore.point("removeEventHandler")

  if (!is.null(eventId)) {
    if (!is.null(id)) {
      app$eventList[[eventId]]$handlers[[id]] = NULL
    } else {
      app$eventList[[eventId]]$glob.handler = NULL
    }
    return()
  }

  #cat("\nremoveEventHandler")
  if (!is.null(id)) {
    ind = which(names(app$handlers) %in% id)
  }
  destroyHandlerObserver(ind, app=app)
  if (length(ind)>0) {
    app$handlers = app$handlers[-ind]
  }
  #cat("\nend removeEventHandler")
}



addEventHandlerToApp = function(id, call, type="unknown", app = getApp(),session.env=app$session.env, if.handler.exists = c("replace","add","skip")[1], intervalMs=NULL, session=getAppSession(app), call.env=NULL, no.authentication.required=FALSE) {
  restore.point("addEventHandlerToApp")
  has.handler = id %in% names(app$handlers)
  if (no.authentication.required) {
    app$events.without.authentication = unique(c(id, app$events.without.authentication))
  }
  if ( (!has.handler) | if.handler.exists == "add") {
    n = length(app$handlers)+1
    app$handlers[[n]] = list(id=id, call=call, type=type, observer=NULL, call.env=call.env)
    names(app$handlers)[n] <- id
    if (app$is.running) {
      app$handlers[[n]]$call.env = initHandlerCallEnv(call.env,session.env)
      app$handlers[[n]]$observer = eval(call,app$handlers[[n]]$call.env)
      #app$handlers[[n]]$observer = eval(call,session.env)
    }
  } else if (if.handler.exists=="replace") {
    if (!is.null(app$handlers[[id]]))
      destroyHandlerObserver(id,app=app)
    app$handlers[[id]] = list(id=id, call=call, type=type, observer=NULL, call.env=call.env)
    if (app$is.running) {
      app$handlers[[id]]$call.env = initHandlerCallEnv(call.env,session.env)
      app$handlers[[id]]$observer = eval(call,app$handlers[[id]]$call.env)
      #app$handlers[[id]]$observer = eval(call,session.env)
    }

  } else {
    # don't add handler
    return()
  }
  if (type == "timer") {
    app$handlers[[id]]$timer = reactiveTimer(intervalMs = intervalMs, session)
  }
}



#' Add an handler to an input that is called when the input value changes
#'
#' @param id name of the input element
#' @param fun function that will be called if the input value changes. The function will be called with the arguments: 'id', 'value' and 'session'. One can assign the same handler functions to several input elements.
#' @param ... extra arguments that will be passed to fun when the event is triggered.
#' @export
changeHandler = function(id, fun,...,app=getApp(), on.create=FALSE, if.handler.exists = c("replace","add","skip")[1], session=getAppSession(app), no.authentication.required=FALSE) {
  #browser()
  if (app$verbose)
    display("\nadd changeHandler for ",id)

  # Create dynamic observer
  args = list(...)

   ca = substitute(env=list(s_id=id, s_fun=fun,s_args=args, s_on.create=on.create),
    observe({
      if (app$verbose)
        display("called event handler for ",s_id)

      input[[s_id]]
      if (hasWidgetValueChanged(s_id, input[[s_id]], on.create=s_on.create)) {
        if (app$verbose)
          display(" run handler...")
        test.event.authentication(id=s_id, app=app)
        
        myfun = s_fun
        do.call(myfun, c(list(id=s_id, value=input[[s_id]], session=session,app=getApp()),s_args))
      }
    })
  )

  addEventHandlerToApp(id=id,call=ca,type="change",app=app, if.handler.exists=if.handler.exists,  no.authentication.required=no.authentication.required)
}


#' Add an handler that triggers every intervalMs milliseconds
#'
#' @param id name of the input element
#' @param fun function that will be called if the input value changes. The function will be called with the arguments: 'id', 'value' and 'session'. One can assign the same handler functions to several input elements.
#' @param ... extra arguments that will be passed to fun when the event is triggered.
timerHandler = function(id,intervalMs, fun,...,app=getApp(), on.create=FALSE, if.handler.exists = c("replace","add","skip")[1], verbose=FALSE, session=getAppSession(app)) {
  #browser()
  if (verbose)
    display("\nadd timerHandler ",id)

  # Create dynamic observer
  args = list(...)

  ca = substitute(env=list(s_id=id, s_fun=fun,s_args=args, s_on.create=on.create,s_verbose=verbose),
    observe({
      if (s_verbose)
        display("\ncalled timer handler ",s_id)
      cURReNTTime = app$handlers[[s_id]]$timer()
      myfun = s_fun
      do.call(myfun, c(list(id=s_id, value=cURReNTTime, session=session,app=app),s_args))
    })
  )

  addEventHandlerToApp(id=id,call=ca,type="timer",app=app, if.handler.exists=if.handler.exists, intervalMs=intervalMs)
}


#' Add an handler to a hotkey in an aceEditor component
#'
#' @param id name of the button
#' @param fun function that will be called if button is pressed. The function will be called with the following arguments:
#'
#'  keyId: the id assigned to the hotkey
#'  editorId: the id of the aceEditor widget
#'  selection: if a text is selected, this selection
#'  text: the text of the aceEditor widget
#'  cursor: a list with the current cursor position:
#'          row and column with index starting with 0
#'  session: the current session object
#' @param ... extra arguments that will be passed to fun when the event is triggered.
aceHotkeyHandler = function(id, fun,..., app = getApp(),if.handler.exists = c("replace","add","skip")[1], session=getAppSession(app),no.authentication.required=FALSE) {

  if (app$verbose)
    display("\nadd aceHotkeyHandler for ",id)

  args = list(...)

  ca = substitute(env=list(s_id=id, s_fun=fun,s_args=args),
    observe({
      #restore.point("jdjfdgbfhdbgh")
      #browser()
      
      if (wasAceHotkeyPressed(s_id, input[[s_id]])) {
        display(s_id, " has been pressed...")
        test.event.authentication(id=s_id, app=app)
        res = input[[s_id]]
        text = isolate(input[[res$editorId]])
        li = c(list(keyId=s_id),res,
               list(text=text,session=session,app=app),s_args)
        myfun = s_fun
        do.call(myfun,li)
      }
    })
  )
  addEventHandlerToApp(id=id,call=ca,type="button",app=app, if.handler.exists=if.handler.exists,no.authentication.required=no.authentication.required)
}



#' Checks whether the value of an input item has been changed (internal function)
hasWidgetValueChanged = function(id, new.value,on.create=FALSE, app = getApp()) {
  restore.point("hasWidgetValueChanged")
  #cat("\nid=",id)
  #cat("\napp$values[[id]]=",app$values[[id]])
  #cat("\nnew.value=",new.value)

  if (!id %in% names(app$values)) {
    if (is.null(new.value)) {
      app$values[id] = list(NULL)
    } else {
      app$values[[id]] = new.value
    }
    changed = on.create
  } else {
    changed = !identical(app$values[[id]],new.value)
    if (changed) {
      if (is.null(new.value)) {
        app$values[id] = list(NULL)
      } else {
        app$values[[id]] = new.value
      }
    }
  }
  return(changed)
}

#' Checks whether a button has been pressed again (internal function)
wasAceHotkeyPressed = function(keyId, value, app = getApp()) {
  restore.point("wasAceHotkeyPressed")

  if (is.null(value))
    return(FALSE)
  old.rand = app$aceHotKeyRandNum[[keyId]]
  app$aceHotKeyRand[[keyId]] = value$randNum

  was.pressed = !identical(value$randNum, old.rand)
  was.pressed
}

#' Set a function that will be called when a new session of
#' an app is initialized.
#'
#'  @param initHandler a function that takes parameters
#'    session, input, output and app. It will be called from
#'    the app$server function whenever a new session is created.
#'    It allows to initialize session specific variables and e.g.
#'    store them within the app object. The passed app object is already
#'    the local copy created for the new session.
appInitHandler = function(initHandler,app=getApp()) {
  app$initHandler = initHandler
}