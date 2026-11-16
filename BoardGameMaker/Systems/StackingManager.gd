extends Node


func create_stack(first: StackableBoardObject, second: StackableBoardObject) -> void:
	var stack: BoardObjectStack = BoardObjectStack.new([first, second])
	GameService.get_board().add_child(stack)
