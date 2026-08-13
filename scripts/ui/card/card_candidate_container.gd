extends CardBase
## 被选择的卡片，卡片被选后留在备选卡槽的卡片
class_name CardCandidateContainer

## 备选卡片的选择卡片
var card:Card


func _ready() -> void:
	super()
	card_id = card.card_id
	sun_cost = card.sun_cost
	## 干员整卡: 背景直接用整卡图(整卡已含角色立绘), 不复制 CharacterStatic
	## (原卡片 CharacterStatic 为整卡模式已隐藏, 复制过来只会显示为白牌/空卡)
	if card.is_operator_card:
		var full_card: Texture2D = card.get_operator_full_card_texture()
		if full_card != null:
			card_bg.texture = full_card
		return
	var character_static_node = card.character_static.duplicate()
	card_bg.add_child(character_static_node)


## 添加到场景树之前初始化备选卡片
func init_card_in_seed_chooser(curr_card:Card):
	self.card = curr_card
	add_child(curr_card)
	curr_card.card_candidate_container = self
