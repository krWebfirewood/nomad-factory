extends Node

const TILE_SIZE = 64

var grid = {} # Vector2i 좌표를 키로 하여 건물 노드를 저장
var ore_grid = {} # Vector2i -> String (광맥 종류)

func register_ore(grid_pos: Vector2i, type: String):
	ore_grid[grid_pos] = type

func get_ore(grid_pos: Vector2i):
	return ore_grid.get(grid_pos)

func register_building(grid_pos: Vector2i, node: Node):
	grid[grid_pos] = node

func remove_building(grid_pos: Vector2i):
	grid.erase(grid_pos)

func get_building(grid_pos: Vector2i) -> Node:
	return grid.get(grid_pos)

func get_local_grid_pos(local_pos: Vector2) -> Vector2i:
	return Vector2i(round(local_pos.x / TILE_SIZE), round(local_pos.y / TILE_SIZE))

func get_local_pos(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)

func get_world_grid_pos(global_pos: Vector2) -> Vector2i:
	return Vector2i(round(global_pos.x / TILE_SIZE), round(global_pos.y / TILE_SIZE))

func get_world_pos(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)
