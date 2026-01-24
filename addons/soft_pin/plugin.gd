@tool
extends EditorPlugin

const SPscript : Script = preload("res://addons/soft_pin/softpin.gd")
var icon : Texture2D = preload("res://addons/soft_pin/softPin Icon.svg")


func _enter_tree():
	# Initialization of the plugin goes here.
	add_custom_type("SoftPin", "Node", SPscript, icon)
	pass


func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_custom_type("SoftPin")
	pass
