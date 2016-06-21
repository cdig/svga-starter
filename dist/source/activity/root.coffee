Take ["Ease", "HydraulicPressure", "PointerInput", "SVGAnimation"], (Ease, HydraulicPressure, PointerInput, SVGAnimation)->
  activity.root = (svgElement)->
    return scope =
      
      setup: ()->
        scope.animation.start()
      
      animation: SVGAnimation (dT, time)->
        
  
  activity.registerInstance("root", "root")
