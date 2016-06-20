activity = {}
activity._name = "%activity_name"
activity._waitingInstances = []

activity.registerInstance = (instanceName, stance)->
  for instance in activity._waitingInstances when instance.name is instanceName
    console.log "Warning: registerInstance(#{instanceName}, #{stance}) — #{instanceName} is already in use. Use a different name, maybe?"
    return
  activity._waitingInstances.push {name: instanceName, instance: stance}

Take "SVGActivities", (SVGActivities)->
  SVGActivities.registerActivityDefinition(activity)
