activity = {}
activity._name = "%activity_name"
activity._instances = [] #make into _instance
activity.registerInstance = (instanceName, stance)->
  for instance in activity._instances
    if instanceName.name is instanceName
      console.warn "#{instanceName} is already in use. Please use another"
      return
  activity._instances.push {name: instanceName, instance: stance}
do ->
  Take "SVGActivities", (SVGActivities)->
    SVGActivities.registerActivityDefinition(activity)