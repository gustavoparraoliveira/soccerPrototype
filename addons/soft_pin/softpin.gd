@icon ("res://addons/soft_pin/softPin Icon.svg")
@tool
extends Node

enum PinState
{
	OFF = 0,
	ON = 1,
}

enum PinType
{
	MESHINSTANCE3D = 0,
	SKELETON3D = 1,
}	


#Variables 
@export var softbody: SoftBody3D
@export var boneattachment: BoneAttachment3D
@export var pin_type:PinType
@export var start_pinning: PinState
@export var pinning_status = "No softbody assigned"

var mesh : Mesh
var vert_amount 
var white_color = Color(1,1,1,1)
var black_color = Color(0,0,0,1)

var meshdatatool = MeshDataTool.new()
var arraymesh = ArrayMesh.new()
var arrays = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	if (Engine.is_editor_hint()):
		if (start_pinning == PinState.ON):
			assign_pins()  
			start_pinning = 0
	
func assign_pins():
	#Set the Mesh resource, Godot Collections Array, Array Mesh , and Mesh Data Tool
		if (softbody != null):
			mesh = softbody.mesh
			arrays = mesh.surface_get_arrays(0)
			arraymesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			meshdatatool.create_from_surface(arraymesh,0)
			pinning_status = "pinning..."
			
			vert_amount = meshdatatool.get_vertex_count()
			
			if (pin_type == PinType.MESHINSTANCE3D):
				if (boneattachment != null):
					printerr("PINTYPE ERROR! SOFTPIN ACTION REQUIRED: SWITCH PINTYPE TO SKELETON3D WHEN USING BONE ATTACHMENT")
					pinning_status = "PINTYPE ERROR! Switch to Skeleton3D"
					return
				for i in range(vert_amount):
					var vertexcolor = meshdatatool.get_vertex_color(i)
					if (vertexcolor != white_color and vertexcolor != black_color):
						#COLOR DETECTED NO PIN
						softbody.set_point_pinned(i,false)
					else:
						#NO COLOR DETECTED SET PIN
						softbody.set_point_pinned(i,true) 
			
			if (pin_type == PinType.SKELETON3D):
				if (boneattachment != null):
					var bonepath = softbody.get_path_to(boneattachment)
					for i in range(vert_amount):
						var vertexcolor = meshdatatool.get_vertex_color(i)
						if (vertexcolor != white_color and vertexcolor != black_color):
							#COLOR DETECTED NO PIN
							softbody.set_point_pinned(i,false)
						else:
							#NO COLOR DETECTED SET PIN
							softbody.set_point_pinned(i,true,bonepath) 
					if(softbody.skeleton != null):
						softbody.skeleton = ""
				else: 
					printerr("NULL REF! SOFTPIN ACTION REQUIRE: ASSIGN BONEATTACHMENT3D")
					pinning_status = "NULL REF! Assign BoneAttachment" 
					return
				
				#Clear
			
			print("SOFTPIN: PINNING COMPLETE")
			pinning_status = softbody.name + " Pinning complete"
			arraymesh.clear_surfaces()
			meshdatatool.clear()
			softbody = null
			boneattachment = null
			
		else: 
			printerr("NULL REF! SOFTPIN ACTION REQUIRE: ASSIGN SOFTBODY3D")
			pinning_status = "NULL REF! Assign Softbody"
