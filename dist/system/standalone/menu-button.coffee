# Note: This was forked from a file in cd-module. Please keep these files in sync.

Take ["cdHUD", "KVStore", "DOMContentLoaded"], (cdHUD, KVStore)->
  
  doClick = ()->
    success = KVStore.save()
    if success
      window.history.back() # TODO: Should probably use Config.parent (or something) here
    else
      ModalPopup.open "Saving Failed", "Check your internet connection and try again."
  
  
  # Set up buttons in content (eg: in ending.kit)
  for button in document.querySelectorAll "[menu-button]"
    button.addEventListener "click", doClick
  
  # Add a HUD Element
  menuButton = document.createElement "menu-button"
  menuButton.innerHTML = "<img src='standalone/lbs-icon.svg'> <span>Back to Menu</span>"
  menuButton.style.order = 1
  cdHUD.addElement menuButton, doClick
