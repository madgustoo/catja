extends Node

var score = 0
@onready var coins_label: Label = $CoinsLabel

func add_point():
	score += 1
	coins_label.text = "You collected " + str(score) + " coins"
