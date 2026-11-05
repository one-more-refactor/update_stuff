# Feature: run detached, come back later, re-attach instead of starting twice.
# Rendered by media/capture.sh -> docs/media/background.gif
Output docs/media/background.gif

Set Shell "bash"
Set FontFamily "JetBrains Mono"
Set FontSize 18
Set Width 1200
Set Height 660
Set Padding 28
Set Margin 0
Set WindowBar Colorful
Set BorderRadius 10
Set TypingSpeed 45ms
Set Theme { "name": "update_stuff", "black": "#0F1420", "red": "#FF6B6B", "green": "#3DDC97", "yellow": "#FFB547", "blue": "#6CB6FF", "magenta": "#C792EA", "cyan": "#5EE6D0", "white": "#E8F1EC", "brightBlack": "#5B6478", "brightRed": "#FF8787", "brightGreen": "#7CF0BE", "brightYellow": "#FFD08A", "brightBlue": "#9CCBFF", "brightMagenta": "#DDB6F2", "brightCyan": "#9AF2E4", "brightWhite": "#FFFFFF", "background": "#0F1420", "foreground": "#E8F1EC", "selection": "#2A3350", "cursor": "#3DDC97" }

Hide
Type "source media/demo-env.sh && clear"
Enter
Sleep 500ms
Show

Hide
Type "export DEMO_SPEED=2"
Enter
Show
Sleep 500ms
Type "sudo update-stuff --detach --hold 3"
Sleep 300ms
Enter
Sleep 1.5s
Type "sudo update-stuff"
Sleep 300ms
Enter
Sleep 1.5s
Type "y"
Enter
Sleep 12s
Sleep 1.5s
