Take "SVGActivities", (SVGActivities)->
  svgActivity = document.querySelector("svg-activity")
  SVGActivities.startActivity(svgActivity.getAttribute("name"), svgActivity.getAttribute("id"), svgActivity.querySelector("object"))
