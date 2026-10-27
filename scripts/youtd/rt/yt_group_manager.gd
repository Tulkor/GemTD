class_name YtGroupManager
extends RefCounted
## Portiert aus YouTD 2 (MIT, github.com/Praytic/youtd2), siehe data/youtd/QUELLEN.md.
## Knoten einer Gruppe nach ihrer Nummer (uid) finden.


static func add(group_name: String, node: Node, _uid: int) -> void:
	node.add_to_group(group_name)


static func get_by_uid(group_name: String, uid: int) -> Node:
	for n in YtWorld.group(group_name):
		if is_instance_valid(n) and not n.is_queued_for_deletion() and n.has_method("get_uid") and n.get_uid() == uid:
			return n
	return null
