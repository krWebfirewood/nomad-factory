# AGENT REFERENCE & GUIDELINES

이 문서는 게임 프로젝트의 기본 아키텍처와 규칙, 그리고 AI 에이전트 및 개발자가 준수해야 할 핵심 가이드라인을 정의합니다.

## 프로젝트 개요
- **엔진**: Godot 4.x (2D)
- **핵심 컨셉**: 거대 이동 요새(`player.gd`) 내부의 5x5 그리드에 다양한 건물(포탑, 채굴기, 가공소 등)을 건설하여 요새를 방어하고 자원을 채집하는 디펜스+팩토리 융합 게임.

## 핵심 시스템 (Core Systems)
1. **`GameManager` (game_manager.gd)**
   - 게임의 전역 상태를 관리하는 싱글톤.
   - 주요 변수: `player`, `boss`, `nexus`, `current_wave`
   - 보스 몬스터 추가 시, 반드시 `GameManager.boss = self` 혹은 생성 로직 안에서 명시적으로 등록해야 UI가 이를 추적할 수 있습니다.

2. **`FactoryManager` (factory_manager.gd)**
   - 5x5 그리드 좌표계 관리를 담당하는 싱글톤.
   - `get_local_grid_pos(local_pos)`: 픽셀 좌표를 그리드 좌표(Vector2i)로 변환.
   - `get_local_pos(grid_pos)`: 그리드 좌표를 픽셀 좌표(타일의 정중앙)로 변환. 타일 크기(`TILE_SIZE`)는 기본 64입니다.

3. **이동 요새 (`player.gd`)**
   - 플레이어 뷰, 건물 배치, 층수(Floor) 시스템, UI 입력 처리를 총괄합니다.
   - `_unhandled_input(event)`에서 건물의 우클릭/좌클릭 선택 처리를 담당하며, 이를 위해 화면을 클릭할 때 광역 좌표를 `get_canvas_transform().affine_inverse() * event.position`를 통해 정밀하게 계산합니다.

## 개발 규칙 및 트러블슈팅 가이드 (Rules & Patterns)

### 1. 건물 상태 데이터 저장 (Metadata 활용)
- 건물(`Node2D` 등)의 속성(레벨, 건물 이름 등)은 상속 구조를 복잡하게 가져가는 대신 **메타데이터**(`set_meta("level", 1)`, `get_meta("b_name")`)를 적극 활용합니다.
- UI 시스템(`player.gd`의 Context UI)이 이 메타데이터를 읽어 동적으로 팝업을 렌더링합니다.

### 2. UI와 클릭 감지 충돌 방지 (Mouse Filter)
- [중요] 건물이나 요소를 렌더링할 때 `ColorRect` 등의 `Control` 노드를 사용하는 경우, 반드시 **`mouse_filter = Control.MOUSE_FILTER_IGNORE`** (값: 2) 처리를 해야 합니다.
- 고도의 기본값(`MOUSE_FILTER_STOP`) 때문에, 마우스 필터 설정을 누락하면 클릭 이벤트가 `ColorRect`에 먹혀버려 `player.gd`의 `_unhandled_input`으로 전달되지 않는 현상(외곽을 클릭해야만 인식되는 버그)이 발생합니다.

### 3. 피격 및 데미지 시스템
- 몬스터 및 보스는 `CharacterBody2D`로 구현되며, 투사체(`Area2D`)와의 충돌을 위해 `collision_layer = 2`를 설정합니다.
- 체력을 깎는 처리는 반드시 노드 내부에 구현된 `take_damage(amount, attack_type)` 메서드를 호출하는 방식을 사용합니다.
- `projectile.gd` 등에서 적을 감지하면 `has_method("take_damage")`로 검사한 후 데미지를 가하고 자신은 `queue_free()` 합니다.

## 작업 기록 체계
- 날짜별 세부 작업 내역, 기획, 오류 및 해결 과정은 `docs/history/YYYY-MM-DD.md` 형태로 저장하여 기록을 보존합니다. 이전 맥락 파악이 필요할 경우 해당 폴더를 참조하세요.
