# ZMK Configuration Plan for Mac-style Keybindings

## 1. Custom Behaviors Section Update

Add these behaviors to your existing Custom Defined Behaviors section:

```c
// Mac-style word navigation with Alt (Option)
alt_left_word: alt_left_word {
    compatible = "zmk,behavior-mod-morph";
    #binding-cells = <0>;
    bindings = <&kp LC(LEFT)>, <&kp LEFT>;
    mods = <(MOD_LSFT|MOD_LCTL)>;
    keep-mods = <(MOD_LSFT|MOD_LCTL)>;
};

alt_right_word: alt_right_word {
    compatible = "zmk,behavior-mod-morph";
    #binding-cells = <0>;
    bindings = <&kp LC(RIGHT)>, <&kp RIGHT>;
    mods = <(MOD_LSFT|MOD_LCTL)>;
    keep-mods = <(MOD_LSFT|MOD_LCTL)>;
};
```

## 2. Macros Section Update

Add these macros to your macros section:

```c
// Delete line left (Cmd+Backspace)
cmd_backspace: cmd_backspace {
    compatible = "zmk,behavior-macro";
    #binding-cells = <0>;
    bindings = <&kp LS(HOME) &kp DELETE>;
};

// Delete line right (Cmd+Delete)
cmd_delete: cmd_delete {
    compatible = "zmk,behavior-macro";
    #binding-cells = <0>;
    bindings = <&kp LS(END) &kp DELETE>;
};
```

## 3. Create a New Mac Layer

In the Glove80 Layout Editor, create a new layer called "Mac" (it will be LAYER_Mac in the code).

## 4. Mac Layer Key Mappings

### 4.1 Basic Mac Shortcuts (Map these on the Mac layer)

| Physical Key | Mac Function | ZMK Binding |
|-------------|--------------|-------------|
| A | Select All | `&kp LC(A)` |
| C | Copy | `&kp LC(INSERT)` |
| V | Paste | `&kp LS(INSERT)` |
| X | Cut | `&kp LS(DELETE)` |
| S | Save | `&kp LC(S)` |
| Z | Undo | `&kp LC(Z)` |
| F | Find | `&kp LC(F)` |
| H | Hide Window | `&kp LA(H)` |
| Q | Quit App | `&kp LA(F4)` |
| W | Close Tab/Window | `&kp LC(W)` |
| T | New Tab | `&kp LC(T)` |
| N | New Window | `&kp LC(N)` |
| O | Open | `&kp LC(O)` |
| P | Print | `&kp LC(P)` |
| R | Refresh | `&kp LC(R)` |

### 4.2 Browser Tab Navigation (Map these on the Mac layer)

| Physical Key | Mac Function | ZMK Binding |
|-------------|--------------|-------------|
| 1 | Tab 1 | `&kp LA(N1)` |
| 2 | Tab 2 | `&kp LA(N2)` |
| 3 | Tab 3 | `&kp LA(N3)` |
| 4 | Tab 4 | `&kp LA(N4)` |
| 5 | Tab 5 | `&kp LA(N5)` |
| 6 | Tab 6 | `&kp LA(N6)` |
| 7 | Tab 7 | `&kp LA(N7)` |
| 8 | Tab 8 | `&kp LA(N8)` |
| 9 | Tab 9 | `&kp LA(N9)` |
| [ | Previous Tab | `&kp LC(PG_UP)` |
| ] | Next Tab | `&kp LC(PG_DN)` |

### 4.3 Navigation Keys (Map these on the Mac layer)

| Physical Key | Mac Function | ZMK Binding |
|-------------|--------------|-------------|
| LEFT | Home (line start) | `&kp HOME` |
| RIGHT | End (line end) | `&kp END` |
| UP | Document Start | `&kp LC(HOME)` |
| DOWN | Document End | `&kp LC(END)` |
| BACKSPACE | Delete Line Left | `&cmd_backspace` |
| DELETE | Delete Line Right | `&cmd_delete` |

### 4.4 Alt Layer Modifications

Create an Alt sub-layer within your Mac layer for word navigation:

| Physical Key | Mac Function | ZMK Binding |
|-------------|--------------|-------------|
| LEFT | Word Left | `&alt_left_word` |
| RIGHT | Word Right | `&alt_right_word` |
| BACKSPACE | Delete Word Left | `&kp LC(BACKSPACE)` |
| DELETE | Delete Word Right | `&kp LC(DELETE)` |

## 5. Layer Activation

### Option 1: Toggle Mac Layer
Add a key on your base layer to toggle the Mac layer:
- Choose a key (e.g., F13 or a key you don't use often)
- Map it to `&tog LAYER_Mac`

### Option 2: Momentary Mac Layer
Add a key that activates Mac layer while held:
- Choose a key (e.g., Right Control)
- Map it to `&mo LAYER_Mac`

### Option 3: Replace a Modifier
Replace one of your GUI keys to always activate the Mac layer:
- Map Left GUI to `&mo LAYER_Mac`
- This makes Left GUI act as Command with all the Mac mappings

## 6. Implementation Steps

1. **Update Custom Behaviors**: Copy the two mod-morph behaviors into your Custom Defined Behaviors section
2. **Update Macros**: Copy the two macros into your macros section
3. **Create Mac Layer**: Add a new layer in the Glove80 Layout Editor
4. **Map Keys**: Go through each key in the tables above and map them in the Mac layer
5. **Choose Activation Method**: Pick one of the three activation methods and add it to your base layer
6. **Test**: Flash your keyboard and test the functionality

## 7. Testing Checklist

After implementing, test these key combinations:

- [ ] Cmd+C copies text
- [ ] Cmd+V pastes text
- [ ] Cmd+X cuts text
- [ ] Cmd+A selects all
- [ ] Cmd+Left goes to line start
- [ ] Cmd+Right goes to line end
- [ ] Alt+Left moves word left
- [ ] Alt+Right moves word right
- [ ] Cmd+1 through Cmd+9 switch browser tabs
- [ ] Cmd+Backspace deletes line left
- [ ] Cmd+Delete deletes line right
- [ ] Alt+Backspace deletes word left
- [ ] Alt+Delete deletes word right
- [ ] Shift+Ctrl+Alt+Arrow (hyper key) still works correctly

## 8. Troubleshooting

If hyper key combinations don't work:
- Verify the mod-morph behaviors are correctly checking for `MOD_LSFT|MOD_LCTL`
- Ensure you're using `&alt_left_word` and `&alt_right_word` instead of direct mappings

If copy/paste doesn't work:
- Some applications may need `&kp LC(C)` instead of `&kp LC(INSERT)` for copy
- Try using the standard Ctrl+C/V/X mappings instead 