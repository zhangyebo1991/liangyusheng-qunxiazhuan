# World Map Demo Design Document

## 1. Overview
The **World Map Demo** is the first phase of the "World Map & Story Production Pipeline". It provides a large-scale world map partitioned into five geographic regions, populated with core landmarks from the Liang Yusheng universe. This scene serves as the high-level entry point for the game world.

## 2. Core Features
- **Large Scale Map**: A 4000x3000 pixel playable area.
- **Five Regions**:
    - Central Plains (中原腹地)
    - Jiangnan/Jinling (江南/金陵)
    - North/Yanjing (北地/燕京)
    - Yanyun/Liaodong/Frontier (燕云/辽东/塞外)
    - Western Regions/Snow Mountain/Border (西域/雪山/边疆)
- **Core Landmarks**: 13 landmarks placed in roughly accurate geographic clusters.
- **Player Movement**: Top-down character movement on the world map.
- **Interaction**: Press 'E' near a landmark to "enter" it (scene transition).
- **Camera**: Follows the player with zoom support.

## 3. Technical Architecture
### 3.1 Scene & Scripts
- **Scene**: `res://scenes/world_map.tscn`
- **Script**: `res://scripts/scenes/world_map_screen.gd` (Extends `map_screen_base.gd`)
- **Landmark Component**: `res://scripts/scenes/world_map_landmark.gd` (Extends `map_interactable.gd`)

### 3.2 Data Structure
New data file: `data/world_map_config.json`
```json
{
  "regions": [
    {
      "id": "central",
      "name": "中原腹地",
      "color": "#e6d5b8",
      "boundary": [[1500, 1000], [2500, 1000], [2500, 2000], [1500, 2000]]
    }
  ],
  "landmarks": [
    {
      "id": "changan",
      "name": "长安",
      "type": "city",
      "region": "central",
      "position": {"x": 1800, "y": 1400},
      "target_map_id": "changan_city"
    }
  ],
  "routes": [
    {"from": "changan", "to": "luoyang"}
  ]
}
```

## 4. Visual Design (Demo Level)
- **Background**: Antique paper/parchment color (`#f4ebd0`).
- **Region Outlines**: Dashed lines with subtle color shading.
- **Landmark Icons**:
    - City: Red Square
    - Sect/Mountain: Blue Triangle
    - Fortress/Zhai: Green Diamond
- **Routes**: Gray dashed lines connecting landmarks.

## 5. Landmarks to Implement
1.  长安 (Changan)
2.  洛阳 (Luoyang)
3.  武当山 (Wudang Mountain)
4.  少林寺 (Shaolin Temple)
5.  氓山 (Mang Mountain)
6.  金刀寨 (Golden Knife Fortress)
7.  苏州 (Suzhou)
8.  太湖 (Taihu)
9.  北京/京师 (Beijing/Capital)
10. 土木堡 (Tumu Fortress)
11. 辽东 (Liaodong)
12. 天山 (Tianshan)
13. 蛇岛 (Snake Island)

## 6. Implementation Steps
1. Create `data/world_map_config.json` with region and landmark data.
2. Create `res://scripts/scenes/world_map_screen.gd` and `res://scripts/scenes/world_map_landmark.gd`.
3. Create `res://scenes/world_map.tscn`.
4. Update `res://scripts/systems/data_repository.gd` to load the new config if needed.
5. Add zooming capability to the camera in `world_map_screen.gd`.
6. Implement region and route drawing logic.
