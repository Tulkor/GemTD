class_name YtVectorUtils
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.


static func vector3_to_vector2(vec3: Vector3) -> Vector2:
	return Vector2(vec3.x, vec3.y)


static func in_range(start: Vector2, end: Vector2, radius: float) -> bool:
	return start.distance_squared_to(end) <= radius * radius
