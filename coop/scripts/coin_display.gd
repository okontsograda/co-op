extends CanvasLayer

@onready var coin_label: Label = $Control/CoinLabel

var current_coins: int = 0


func _ready() -> void:
	# Initialize display
	update_display()


func update_coins(coins: int) -> void:
	current_coins = coins
	update_display()


func update_display() -> void:
	if coin_label:
		# Display with coin emoji/symbol
		coin_label.text = "💰 " + str(current_coins)

