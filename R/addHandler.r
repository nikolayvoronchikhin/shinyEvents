# Manually trigger shiny events when some value changes
# While this is also the key idea of reactive programming
# Shiny (at least in current versions as of October 2014)
# tends to trigger events too often.

# What we need:
#   1. Call a function or render output when a button is clicked
#   2. Call a function or render output when an input value has changed
#   3. Update input values when an input value or variable has changed without triggering further events


resetEventHandlers = function(app = getApp()) {
  app$values=list()  
}

addEventHandlersToSession = function(handlers, session.env=app$session.env, app=getApp()) {
  for (el in handlers) {
    call = el$call
    eval(call, session.env)
  }
}

addEventHandlerToApp = function(id, call, type="unknown", app = getApp(),session.env=app$session.env) {
  n = length(app$handlers)+1
  app$handlers[[n]] = list(id=id, call=call, type=type)
  names(app$handlers)[n] <- id
  if (app$is.running) {
    eval(call,app$session.env)
  }
}

#' Add an handler to an input that is called when the input value changes
#' 
#' @param id name of the input element
#' @param fun function that will be called if the input value changes. The function will be called with the arguments: 'id', 'value' and 'session'. One can assign the same handler functions to several input elements.
addChangeHandler = function(id, fun,...,app=getApp(), on.create=FALSE) {
  #browser()
  fun = substitute(fun)
  # Create dynamic observer
  args = list(...)
  ca = substitute(env=list(s_id=id, s_fun=fun,s_args=args, s_on.create=on.create),
    observe({
      display("called event handler for ",s_id)
      input[[s_id]]
      if (hasWidgetValueChanged(s_id, input[[s_id]], on.create=s_on.create)) {
        display("run event handler for ",s_id)
        do.call(s_fun, c(list(id=s_id, value=input[[s_id]], session=session),s_args))
      }
    })
  )
  addEventHandlerToApp(id=id,call=ca,type="change",app=app)
}


#' Add an handler to a button
#' 
#' @param id name of the button
#' @param fun function that will be called if button is pressed. The function will be called with the arguments: 'id', 'value' and 'session'. One can assign the same handler functions to several buttons.
addButtonHandler = function(id, fun,..., app = getApp()) {
  
  if (app$verbose)
    display("\naddButtonHandler('",id,'",...)')
  
  fun = substitute(fun)
  args = list(...)

  ca = substitute(env=list(s_id=id, s_fun=fun,s_args=args),
    observe({
      if (hasButtonCounterIncreased(s_id, input[[s_id]])) {
        display(s_id, " has been clicked...")
        do.call(s_fun, c(list(id=s_id, value=input[[s_id]], session=session),s_args))
      }
    })
  )
  addEventHandlerToApp(id=id,call=ca,type="button",app=app)
}


#' Checks whether the value of an input item has been changed (internal function)
hasWidgetValueChanged = function(id, new.value,on.create=FALSE, app = getApp()) {
  restore.point("hasWidgetValueChanged")
  if (!id %in% names(app$values)) {
    app$values[[id]] = new.value
    changed = on.create
  } else {
    changed = !identical(app$values[[id]],new.value)
    if (changed) {
      app$values[[id]] = new.value
    }
  }
  return(changed)
}

#' Checks whether a button has been pressed again (internal function)
hasButtonCounterIncreased = function(id, counter, app=getApp()) {
  restore.point("hasButtonCounterIncreased")
  if (isTRUE(counter == 0) | is.null(counter) | isTRUE(counter<=app$values[[id]])) {
    app$values[[id]] = counter
    cat("\nno counter increase: ", id, " ",counter)
    return(FALSE)
  }
  app$values[[id]] = counter
  cat("\ncounter has increased: ", id, " ",counter)
  return(TRUE)  
}
