extends Node


func create_stack(first: StackableBoardObject, second: StackableBoardObject) -> void:
	if first.is_in_stack() or second.is_in_stack():
		return
	
	var stack: BoardObjectStack = BoardObjectStack.new([first, second])
	GameService.get_board().add_child(stack)
