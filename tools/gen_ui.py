# UI 씬(.tscn) 생성기. 메뉴 레이아웃을 한 곳에서 관리하려고 만든 개발용 도구.
# 사용법: python tools/gen_ui.py  (프로젝트 루트에서)
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "scenes", "ui")
FULL = {"layout_mode": 1, "anchors_preset": 15, "anchor_right": 1.0, "anchor_bottom": 1.0, "grow_horizontal": 2, "grow_vertical": 2}


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str) and (v.startswith("Color(") or v.startswith("Vector2(") or v.startswith("ExtResource(") or v.startswith("SubResource(")):
        return v
    if isinstance(v, str):
        return '"' + v.replace('"', '\\"') + '"'
    raise ValueError(v)


class Scene:
    def __init__(self, script):
        self.ext = []
        self.subs = []
        self.nodes = []
        self.add_ext("Script", script, "1_script")
        self.add_ext("FontFile", "res://assets/fonts/BlackHanSans-Regular.ttf", "2_big")

    def add_ext(self, t, path, id_):
        self.ext.append((t, path, id_))

    def sub(self, t, id_, props):
        self.subs.append((t, id_, props))

    def node(self, name, t, parent=None, **props):
        self.nodes.append((name, t, parent, props))

    def write(self, fname):
        out = ["[gd_scene format=3]", ""]
        for t, p, i in self.ext:
            out.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        out.append("")
        for t, i, props in self.subs:
            out.append(f'[sub_resource type="{t}" id="{i}"]')
            for k, v in props.items():
                out.append(f"{k} = {val(v)}")
            out.append("")
        for name, t, parent, props in self.nodes:
            head = f'[node name="{name}" type="{t}"'
            if parent is not None:
                head += f' parent="{parent}"'
            head += "]"
            out.append(head)
            for k, v in props.items():
                out.append(f"{k.replace('__', '/')} = {val(v)}")
            out.append("")
        with open(os.path.join(ROOT, fname), "w", encoding="utf-8") as f:
            f.write("\n".join(out))


def title_ls(s, size=56, color="Color(1, 0.86, 0.4, 1)"):
    s.sub("LabelSettings", "ls_title", {"font": 'ExtResource("2_big")', "font_size": size, "font_color": color, "outline_size": 8, "outline_color": "Color(0, 0, 0, 0.5)"})


def panel_scene(script, root_name, width, dim=0.6):
    s = Scene(script)
    title_ls(s)
    s.sub("LabelSettings", "ls_body", {"font_size": 22, "font_color": "Color(0.9, 0.92, 0.94, 1)"})
    s.node(root_name, "Control", None, layout_mode=3, anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2, script='ExtResource("1_script")')
    s.node("Dim", "ColorRect", ".", **FULL, color=f"Color(0.01, 0.02, 0.03, {dim})")
    s.node("Center", "CenterContainer", ".", **FULL)
    s.node("Panel", "PanelContainer", "Center", custom_minimum_size=f"Vector2({width}, 0)", layout_mode=2)
    s.node("VBox", "VBoxContainer", "Center/Panel", layout_mode=2, theme_override_constants__separation=14)
    s.node("Title", "Label", "Center/Panel/VBox", layout_mode=2, text="TITLE", label_settings='SubResource("ls_title")', horizontal_alignment=1)
    return s


V = "Center/Panel/VBox"


def btn(s, name, parent=V, text=""):
    s.node(name, "Button", parent, layout_mode=2, text=text or name)


def main():
    os.makedirs(ROOT, exist_ok=True)

    # 로딩
    s = Scene("res://scripts/ui/loading_screen.gd")
    title_ls(s, 140, "Color(0.96, 0.95, 0.9, 1)")
    s.node("Loading", "Control", None, layout_mode=3, anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2, script='ExtResource("1_script")')
    s.node("Bg", "ColorRect", ".", **FULL, color="Color(0.04, 0.05, 0.07, 1)")
    s.node("Center", "VBoxContainer", ".", layout_mode=1, anchors_preset=8, anchor_left=0.5, anchor_top=0.5, anchor_right=0.5, anchor_bottom=0.5, offset_left=-400.0, offset_top=-140.0, offset_right=400.0, offset_bottom=140.0, grow_horizontal=2, grow_vertical=2, alignment=1)
    s.node("Logo", "Label", "Center", layout_mode=2, text="STOOP", label_settings='SubResource("ls_title")', horizontal_alignment=1)
    s.node("Status", "Label", "Center", layout_mode=2, text="...", horizontal_alignment=1)
    s.write("loading.tscn")

    # 타이틀
    s = Scene("res://scripts/ui/title_menu.gd")
    title_ls(s, 168, "Color(0.97, 0.96, 0.92, 1)")
    s.sub("LabelSettings", "ls_tag", {"font_size": 30, "font_color": "Color(1, 0.86, 0.45, 1)", "outline_size": 6, "outline_color": "Color(0, 0, 0, 0.5)"})
    s.sub("LabelSettings", "ls_foot", {"font_size": 16, "font_color": "Color(1, 1, 1, 0.6)"})
    s.node("Title", "Control", None, layout_mode=3, anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2, script='ExtResource("1_script")')
    s.node("Shade", "ColorRect", ".", layout_mode=1, anchors_preset=9, anchor_bottom=1.0, offset_right=760.0, grow_vertical=2, color="Color(0.02, 0.03, 0.05, 0.55)")
    s.node("Left", "VBoxContainer", ".", layout_mode=1, anchors_preset=4, anchor_top=0.5, anchor_bottom=0.5, offset_left=110.0, offset_top=-360.0, offset_right=650.0, offset_bottom=360.0, grow_vertical=2, theme_override_constants__separation=12, alignment=1)
    s.node("Logo", "Label", "Left", layout_mode=2, text="STOOP", label_settings='SubResource("ls_title")')
    s.node("Tag", "Label", "Left", layout_mode=2, text="송골매의 삶", label_settings='SubResource("ls_tag")')
    s.node("Space", "Control", "Left", custom_minimum_size="Vector2(0, 36)", layout_mode=2)
    for b in ["Continue", "NewGame", "Records", "Settings", "Controls", "Credits", "Quit"]:
        btn(s, b, "Left")
    s.node("Footer", "Label", ".", layout_mode=1, anchors_preset=3, anchor_left=1.0, anchor_top=1.0, anchor_right=1.0, anchor_bottom=1.0, offset_left=-700.0, offset_top=-50.0, offset_right=-30.0, offset_bottom=-20.0, grow_horizontal=0, grow_vertical=0, text="v0.9", label_settings='SubResource("ls_foot")', horizontal_alignment=2)
    s.write("title_menu.tscn")

    # 새 게임
    s = panel_scene("res://scripts/ui/new_game_menu.gd", "NewGame", 760)
    s.node("NameLabel", "Label", V, layout_mode=2, text="이름", label_settings='SubResource("ls_body")')
    s.node("Name", "LineEdit", V, layout_mode=2, text="바람", max_length=10)
    s.node("SexLabel", "Label", V, layout_mode=2, text="성별", label_settings='SubResource("ls_body")')
    s.node("Sex", "HBoxContainer", V, layout_mode=2, theme_override_constants__separation=12)
    s.node("Male", "Button", V + "/Sex", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text="수컷")
    s.node("Female", "Button", V + "/Sex", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text="암컷")
    s.node("SexDesc", "Label", V, custom_minimum_size="Vector2(700, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
    s.node("DiffLabel", "Label", V, layout_mode=2, text="난이도", label_settings='SubResource("ls_body")')
    s.node("Diff", "HBoxContainer", V, layout_mode=2, theme_override_constants__separation=12)
    s.node("Normal", "Button", V + "/Diff", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text="보통")
    s.node("Wild", "Button", V + "/Diff", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text="야생")
    s.node("DiffDesc", "Label", V, custom_minimum_size="Vector2(700, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
    s.node("TutLabel", "Label", V, layout_mode=2, text="시작", label_settings='SubResource("ls_body")')
    s.node("Tut", "HBoxContainer", V, layout_mode=2, theme_override_constants__separation=12)
    s.node("TutOn", "Button", V + "/Tut", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text="알에서부터")
    s.node("TutOff", "Button", V + "/Tut", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text="건너뛰기")
    s.node("Row", "HBoxContainer", V, layout_mode=2, theme_override_constants__separation=12, alignment=2)
    s.node("Back", "Button", V + "/Row", layout_mode=2, text="뒤로")
    s.node("Start", "Button", V + "/Row", layout_mode=2, text="시작")
    s.write("new_game_menu.tscn")

    # 일시정지
    s = panel_scene("res://scripts/ui/pause_menu.gd", "Pause", 520)
    for b in ["Resume", "Map", "Growth", "Records", "Settings", "Controls", "SkipTut", "SaveQuit", "QuitGame"]:
        btn(s, b)
    s.write("pause_menu.tscn")

    # 설정
    s = panel_scene("res://scripts/ui/settings_menu.gd", "Settings", 860)
    s.node("Scroll", "ScrollContainer", V, custom_minimum_size="Vector2(820, 560)", layout_mode=2, horizontal_scroll_mode=0)
    s.node("Grid", "GridContainer", V + "/Scroll", layout_mode=2, size_flags_horizontal=3, theme_override_constants__h_separation=24, theme_override_constants__v_separation=12, columns=2)
    btn(s, "Back")
    s.write("settings_menu.tscn")

    # 조작법
    s = panel_scene("res://scripts/ui/controls_screen.gd", "Controls", 820)
    s.node("Grid", "GridContainer", V, layout_mode=2, theme_override_constants__h_separation=30, theme_override_constants__v_separation=8, columns=2)
    s.node("Tip", "Label", V, custom_minimum_size="Vector2(760, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
    btn(s, "Back")
    s.write("controls_screen.tscn")

    # 크레딧
    s = panel_scene("res://scripts/ui/credits_screen.gd", "Credits", 900)
    s.node("Scroll", "ScrollContainer", V, custom_minimum_size="Vector2(860, 560)", layout_mode=2, horizontal_scroll_mode=0)
    s.node("Text", "Label", V + "/Scroll", custom_minimum_size="Vector2(820, 0)", layout_mode=2, size_flags_horizontal=3, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
    btn(s, "Back")
    s.write("credits_screen.tscn")

    # 기록(업적)
    s = panel_scene("res://scripts/ui/records_screen.gd", "Records", 820)
    s.node("Count", "Label", V, layout_mode=2, text="", label_settings='SubResource("ls_body")', horizontal_alignment=1)
    s.node("Scroll", "ScrollContainer", V, custom_minimum_size="Vector2(780, 560)", layout_mode=2, horizontal_scroll_mode=0)
    s.node("List", "VBoxContainer", V + "/Scroll", layout_mode=2, size_flags_horizontal=3, theme_override_constants__separation=10)
    btn(s, "Back")
    s.write("records_screen.tscn")

    # 성장
    s = panel_scene("res://scripts/ui/growth_screen.gd", "Growth", 860)
    s.node("Level", "Label", V, layout_mode=2, text="", label_settings='SubResource("ls_body")', horizontal_alignment=1)
    s.node("Skills", "GridContainer", V, layout_mode=2, theme_override_constants__h_separation=20, theme_override_constants__v_separation=14, columns=3)
    for sk in ["dive", "wing", "stamina", "eye"]:
        s.node("Name_" + sk, "Label", V + "/Skills", custom_minimum_size="Vector2(600, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
        s.node("Pips_" + sk, "Label", V + "/Skills", layout_mode=2, text="", label_settings='SubResource("ls_body")')
        s.node("Up_" + sk, "Button", V + "/Skills", custom_minimum_size="Vector2(60, 0)", layout_mode=2, text="+")
    s.node("PlumageLabel", "Label", V, layout_mode=2, text="", label_settings='SubResource("ls_body")')
    s.node("Plumage", "HBoxContainer", V, layout_mode=2, theme_override_constants__separation=8)
    for pl in ["default", "silver", "rufous", "dark", "white"]:
        s.node("Pl_" + pl, "Button", V + "/Plumage", layout_mode=2, size_flags_horizontal=3, toggle_mode=True, text=pl)
    btn(s, "Back")
    s.write("growth_screen.tscn")

    # 둥지(휴식)
    s = panel_scene("res://scripts/ui/rest_menu.gd", "Rest", 620)
    s.node("Status", "Label", V, custom_minimum_size="Vector2(560, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
    for b in ["Sleep", "Nap", "Save", "Fly", "Back"]:
        btn(s, b)
    s.write("rest_menu.tscn")

    # 한 해 결산
    s = panel_scene("res://scripts/ui/summary_screen.gd", "Summary", 720)
    s.node("Stats", "GridContainer", V, layout_mode=2, theme_override_constants__h_separation=40, theme_override_constants__v_separation=10, columns=2)
    s.node("Note", "Label", V, custom_minimum_size="Vector2(660, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', autowrap_mode=3)
    btn(s, "Next")
    s.write("summary_screen.tscn")

    # 죽음/혈통
    s = panel_scene("res://scripts/ui/death_screen.gd", "Death", 820, 0.75)
    s.node("Cause", "Label", V, custom_minimum_size="Vector2(760, 0)", layout_mode=2, text="", label_settings='SubResource("ls_body")', horizontal_alignment=1, autowrap_mode=3)
    s.node("Lineage", "VBoxContainer", V, layout_mode=2, theme_override_constants__separation=4)
    s.node("ChooseLabel", "Label", V, layout_mode=2, text="", label_settings='SubResource("ls_body")')
    s.node("Choices", "VBoxContainer", V, layout_mode=2, theme_override_constants__separation=8)
    btn(s, "ToTitle")
    s.write("death_screen.tscn")

    # 지도
    s = Scene("res://scripts/ui/map_screen.gd")
    title_ls(s, 44)
    s.add_ext("Script", "res://scripts/ui/map_overlay.gd", "3_overlay")
    s.node("Map", "Control", None, layout_mode=3, anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2, script='ExtResource("1_script")')
    s.node("Dim", "ColorRect", ".", **FULL, color="Color(0.01, 0.02, 0.03, 0.8)")
    s.node("Center", "CenterContainer", ".", **FULL)
    s.node("VBox", "VBoxContainer", "Center", layout_mode=2, theme_override_constants__separation=10)
    s.node("Title", "Label", "Center/VBox", layout_mode=2, text="지도", label_settings='SubResource("ls_title")', horizontal_alignment=1)
    s.node("Frame", "PanelContainer", "Center/VBox", layout_mode=2)
    s.node("Image", "TextureRect", "Center/VBox/Frame", custom_minimum_size="Vector2(1320, 840)", layout_mode=2, expand_mode=1, stretch_mode=5)
    s.node("Overlay", "Control", "Center/VBox/Frame/Image", **FULL, mouse_filter=2, script='ExtResource("3_overlay")')
    s.node("Hint", "Label", "Center/VBox", layout_mode=2, text="", horizontal_alignment=1)
    s.write("map_screen.tscn")

    # 메뉴 묶음
    out = ["[gd_scene format=3]", "", '[ext_resource type="Script" path="res://scripts/ui/menus.gd" id="1_script"]']
    names = ["loading", "title_menu", "new_game_menu", "pause_menu", "settings_menu", "controls_screen", "credits_screen", "rest_menu", "summary_screen", "death_screen", "map_screen", "records_screen", "growth_screen"]
    for i, n in enumerate(names):
        out.append(f'[ext_resource type="PackedScene" path="res://scenes/ui/{n}.tscn" id="{i + 2}_{n}"]')
    out += ["", '[node name="Menus" type="Control"]', "process_mode = 3", "layout_mode = 3", "anchors_preset = 15", "anchor_right = 1.0", "anchor_bottom = 1.0", "grow_horizontal = 2", "grow_vertical = 2", "mouse_filter = 2", 'script = ExtResource("1_script")', ""]
    node_names = ["Loading", "Title", "NewGame", "Pause", "Settings", "Controls", "Credits", "Rest", "Summary", "Death", "Map", "Records", "Growth"]
    for i, (n, nn) in enumerate(zip(names, node_names)):
        out += [f'[node name="{nn}" parent="." instance=ExtResource("{i + 2}_{n}")]', "visible = false", "layout_mode = 1", ""]
    with open(os.path.join(ROOT, "menus.tscn"), "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print("ok")


if __name__ == "__main__":
    main()
