# SVG Activity Starter
A project for making activities/animations with SVGs to either be used inside of a module or as a stand alone page. For documentation on specifics of SVGs, look up [SVG Activity Components](https://github.com/cdig/svg-activity-components). To get started, [download a copy of this project](https://github.com/cdig/svg-activity-starter/archive/v2.zip). Take the ```dist``` folder and rename it something else.

## Steps to getting an SVG up and running.
- cd into renamed ```dist``` folder
- Run setup commands
```
  npm install
  bower updatet
```
- Place SVG file you're working with into *source/assets* directory
- Edit svg-activity.json's ```name``` property
  - Set this name to be whatever you want it to be for the SVG. 
  - **Note** This is what the SVG will be named in the future. This includes how you reference it in the HTML. If you change the name of the SVG after compilation, make sure to delete any files created as a result as this could lead to conflicts.
- Edit index.kit to reference the SVG name and the SVG file in your public directory. Each SVG Activity, when placed on a page, needs a name which references the name of activity (specified in svg-activity.json), a unique ID, and the object inside of that svg-activity's data property. Below is an example with the default activity passed in, "big-hose.svg"
```html
<svg-activity name="default-activity" id="test_id">
  <object type="image/svg+xml" data="big-hose.svg">Your browser does not support SVG</object>
</svg-activity> 
```
- Add your symbol definitions to the ```source/activity``` folder. This folder works the same as it always has with SVG Activities. For more information, check out [SVG Activity Components] (https://github.com/cdig/svg-activity-components)
- Compile with GULP
From inside of your home directory, run the ```gulp``` command, and the SVG Activity will open up in your browser!
  

