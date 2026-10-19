class_name Finger
extends RefCounted
## The one finger a control follows. A web build's touch index is the browser's
## Touch.identifier, which iOS Safari makes large and arbitrary (never 0), so a
## control cannot filter on index 0: it follows whichever finger pressed on it.
## A new press always takes over, so a release the browser never delivered can
## never lock the control; drags and the release of any other finger are ignored.

var _index := -1


## True when `event` is a touch or drag of the followed finger (a press adopts its finger).
func follows(event: InputEvent) -> bool:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_index = touch.index
			return true
		if touch.index != _index:
			return false
		_index = -1
		return true
	var drag := event as InputEventScreenDrag
	return drag != null and drag.index == _index
