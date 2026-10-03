extends Node2D


@onready var transition_scene_packed = preload("res://modules/SceneTransitioner/scenes/scene_transition.tscn")

var transition_scene
var transition_animation: AnimationPlayer
var default_params = SceneTransitionParams.new()


func _ready() -> void:
	transition_scene = transition_scene_packed.instantiate()
	transition_animation = transition_scene.get_node("AnimationPlayer")
	
	get_tree().get_root().add_child.call_deferred(transition_scene)


func transition_to_scene(current_scene: Node, new_scene: PackedScene, params: SceneTransitionParams = default_params):
	transition_animation.play("fade_in")
	await transition_animation.animation_finished
	
	var new_scene_instance = new_scene.instantiate()
	get_tree().get_root().get_node("Main").add_child(new_scene_instance)
	
	match params.first_scene_action:
		SceneTransitionParams.FirstSceneAction.DELETE:
			current_scene.queue_free()
		
		SceneTransitionParams.FirstSceneAction.HIDE:
			current_scene.hide()
			current_scene.process_mode = Node.PROCESS_MODE_DISABLED
		
		_: pass
	
	await get_tree().create_timer(0.2).timeout
	transition_animation.play("fade_out")
	
	return new_scene_instance
