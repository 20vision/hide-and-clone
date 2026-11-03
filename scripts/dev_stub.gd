extends Node
## Dev only: stands in for the game when rendering figure previews.
var phase := "seek"
var glass_ids: Array = []
var nav = null
func random_spot() -> Vector3: return nav.random_spot() if nav else Vector3.ZERO
func is_hiding_look(c: Clone) -> bool: return glass_ids.has(c.pid)
func visibility() -> float: return 0.12
func show_label(_c: Clone) -> bool: return false
