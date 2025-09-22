#!/usr/bin/env python3
"""
Rofi Terminal History Menu
A beautiful history browser using Rofi with search, edit, and clipboard integration
"""

import os
import sys
import subprocess
import tempfile
import json
from pathlib import Path
from datetime import datetime
import re
import argparse
from typing import List, Dict, Optional
import tailer

class HistoryManager:
    def __init__(self):
        self.history_file = self.get_history_file()
        self.commands = []

    def get_history_file(self):
        """Get the appropriate history file based on shell"""
        shell = os.environ.get('SHELL', '').split('/')[-1]
        home = Path.home()
        
        if shell == 'fish':
            return home / '.local/share/fish/fish_history'
        elif shell == 'zsh':
            return home / '.zsh_history' 
        elif shell == 'bash':
            return home / '.bash_history'
        else:
            # Try common locations
            for hist_file in ['.local/share/fish/fish_history', '.zsh_history', '.bash_history', '.history']:
                path = home / hist_file
                if path.exists():
                    return path
        
        return home / '.bash_history'

    def load_history(self, max_commands=1000) -> bool:
        """Load the most recent command history from file"""
        if not self.history_file.exists():
            self.show_error(f"History file not found: {self.history_file}")
            return False

        try:
            self.commands = []
            seen_commands = set()

            if 'fish_history' in str(self.history_file):
                # Read the last ~3000 lines (approx. 1000 fish history entries)
                with open(self.history_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = tailer.tail(f, 3 * max_commands)  # Estimate: ~3 lines per entry
                    content = '\n'.join(lines)
                    entries = content.split('- cmd: ')[1:]  # Skip empty first entry

                    for entry in entries:
                        lines = entry.strip().split('\n')
                        if not lines:
                            continue
                        command = lines[0].strip()
                        timestamp = None
                        for line in lines[1:]:
                            if line.strip().startswith('when: '):
                                try:
                                    ts = int(line.strip().split('when: ')[1])
                                    timestamp = datetime.fromtimestamp(ts)
                                except (ValueError, IndexError):
                                    pass
                                break
                        if command and command not in seen_commands:
                            seen_commands.add(command)
                            self.commands.append({
                                'command': command,
                                'timestamp': timestamp
                            })
            else:
                # Handle bash/zsh history
                with open(self.history_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = tailer.tail(f, max_commands)
                    for line in lines:
                        line = line.strip()
                        if not line:
                            continue
                        timestamp = None
                        command = line
                        if line.startswith(': ') and ';' in line:
                            try:
                                parts = line[2:].split(';', 1)
                                if len(parts) == 2:
                                    ts_part = parts[0].split(':')[0]
                                    timestamp = datetime.fromtimestamp(int(ts_part))
                                    command = parts[1]
                            except (ValueError, IndexError):
                                pass
                        if command and command not in seen_commands:
                            seen_commands.add(command)
                            self.commands.append({
                                'command': command,
                                'timestamp': timestamp
                            })

            # Assign line numbers in reverse order
            total_commands = len(self.commands)
            for i, cmd in enumerate(self.commands):
                cmd['line_number'] = i + 1
            self.commands.reverse()  # Most recent first

            return True

        except Exception as e:
            self.show_error(f"Error reading history: {e}")
            return False

    def format_command_for_rofi(self, cmd: dict, show_timestamps: bool = True, show_line_numbers: bool = True, max_length: int = 80) -> str:
        """Format command for Rofi display"""
        command = cmd['command']
        parts = []
        
        # Add line number if available and requested
        if show_line_numbers and 'line_number' in cmd:
            parts.append(f"#{cmd['line_number']:04d}")
        
        # Truncate long commands
        if len(command) > max_length:
            command = command[:max_length-3] + "…"
        
        # Join all parts with separator
        if parts:
            return f"{' │ '.join(parts)} │ {command}"
        
        return command

    def show_error(self, message: str):
        """Show error using rofi"""
        subprocess.run(['rofi', '-e', message], timeout=10)

    def show_notification(self, message: str):
        """Show notification"""
        try:
            subprocess.run(['notify-send', 'History Menu', message], timeout=3, capture_output=True)
        except:
            pass  # Notifications are optional

class RofiHistoryMenu:
    def __init__(self, show_timestamps: bool = True, show_line_numbers: bool = True, edit_mode: bool = False):
        self.history_manager = HistoryManager()
        self.show_timestamps = show_timestamps
        self.show_line_numbers = show_line_numbers
        self.edit_mode = edit_mode
        
    def get_rofi_theme(self) -> str:
        """Get Rofi theme configuration based on clipboard theme"""
        return """
/*****----- Configuration -----*****/
configuration {
    show-icons:                 false;
    case-sensitive:             false;
    font:                       "JetBrains Mono 10";
    display-history:            "📜 History";
}

@import                          "~/.config/rofi/launchers/type-1/shared/colors.rasi"
@import                          "~/.config/rofi/launchers/type-1/shared/fonts.rasi"

* {
    border-colour:               var(selected);
    handle-colour:               var(selected);
    background-colour:           var(background);
    foreground-colour:           var(foreground);
    alternate-background:        var(background-alt);
    normal-background:           var(background);
    normal-foreground:           var(foreground);
    urgent-background:           var(urgent);
    urgent-foreground:           var(background);
    active-background:           var(active);
    active-foreground:           var(background);
    selected-normal-background:  var(selected);
    selected-normal-foreground:  var(background);
    selected-urgent-background:  var(active);
    selected-urgent-foreground:  var(background);
    selected-active-background:  var(urgent);
    selected-active-foreground:  var(background);
    alternate-normal-background: var(background);
    alternate-normal-foreground: var(foreground);
    alternate-urgent-background: var(urgent);
    alternate-urgent-foreground: var(background);
    alternate-active-background: var(active);
    alternate-active-foreground: var(background);
    transparent:                 #00000000;

    shadow-colour:               #00000040;
    accent-colour:               var(selected);
    subtle-background:           var(background-alt);
    gradient-start:              var(background);
    gradient-end:                var(background-alt);
}

/*****----- Main Window -----*****/
window {
    location:                    center;
    anchor:                      center;
    fullscreen:                  false;
    width:                       900px;
    height:                      600px;
    x-offset:                    0px;
    y-offset:                    0px;
    margin:                      0px;
    padding:                     0px;
    border:                      2px solid;
    border-radius:               12px;
    cursor:                      "default";
    background-color:            @background-colour;
}

/*****----- Main Box -----*****/
mainbox {
    enabled:                     true;
    spacing:                     12px;
    margin:                      0px;
    padding:                     24px;
    background-color:            @transparent;
    children:                    [ "inputbar", "message", "listview" ];
}

/*****----- Inputbar -----*****/
inputbar {
    enabled:                     true;
    spacing:                     12px;
    padding:                     12px 16px;
    border:                      0px;
    border-radius:               10px;
    border-color:                @border-colour;
    background-color:            @alternate-background;
    text-color:                  @foreground-colour;
    children:                    [ "textbox-prompt-colon", "entry" ];
}

textbox-prompt-colon {
    enabled:                     true;
    expand:                      false;
    str:                         "📜";
    padding:                     6px 8px 6px 0px;
    border-radius:               0px;
    background-color:            inherit;
    text-color:                  @accent-colour;
    font:                        "JetBrains Mono Bold 14";
}

entry {
    enabled:                     true;
    padding:                     8px 0px;
    border-radius:               0px;
    background-color:            inherit;
    text-color:                  inherit;
    cursor:                      text;
    placeholder:                 "Search command history...";
    placeholder-color:           @alternate-normal-foreground;
    font:                        "JetBrains Mono 11";
}

/*****----- Message -----*****/
message {
    enabled:                     true;
    margin:                      0px;
    padding:                     0px 0px 10px 0px;
    border:                      0px solid;
    border-radius:               0px;
    border-color:                @border-colour;
    background-color:            transparent;
    text-color:                  @foreground-colour;
}

textbox {
    padding:                     12px 16px;
    border:                      1px solid;
    border-radius:               8px;
    border-color:                @accent-colour;
    background-color:            @subtle-background;
    text-color:                  @foreground-colour;
    vertical-align:              0.5;
    horizontal-align:            0.0;
    font:                        "JetBrains Mono 9";
}

/*****----- Listview -----*****/
listview {
    enabled:                     true;
    columns:                     1;
    lines:                       10;
    cycle:                       false;
    dynamic:                     true;
    scrollbar:                   true;
    layout:                      vertical;
    reverse:                     false;
    fixed-height:                false;
    fixed-columns:               true;
    
    spacing:                     3px;
    margin:                      15px 0px;
    padding:                     10px;
    border:                      2px solid;
    border-radius:               10px;
    border-color:                @border-colour;
    background-color:            @normal-background;
    text-color:                  @foreground-colour;
    cursor:                      "default";
}

scrollbar {
    handle-width:                6px;
    border:                      0;
    handle-color:                @handle-colour;
    padding:                     4px;
    margin:                      0px 4px 0px 0px;
    border-radius:               8px;
    background-color:            @alternate-background;
}

/*****----- Elements -----*****/
element {
    enabled:                     true;
    spacing:                     8px;
    margin:                      0px;
    padding:                     12px 16px;
    border:                      0px solid;
    border-radius:               8px;
    border-color:                @border-colour;
    background-color:            transparent;
    text-color:                  @foreground-colour;
    cursor:                      pointer;
}

element normal.normal {
    background-color:            @normal-background;
    text-color:                  @normal-foreground;
}

element normal.urgent {
    background-color:            @urgent-background;
    text-color:                  @urgent-foreground;
}

element normal.active {
    background-color:            @active-background;
    text-color:                  @active-foreground;
}

element selected.normal {
    background-color:            @selected-normal-background;
    text-color:                  @selected-normal-foreground;
    border:                      1px solid;
    border-color:                @accent-colour;
}

element selected.urgent {
    background-color:            @selected-urgent-background;
    text-color:                  @selected-urgent-foreground;
}

element selected.active {
    background-color:            @selected-active-background;
    text-color:                  @selected-active-foreground;
}

element-icon {
    background-color:            transparent;
    text-color:                  inherit;
    size:                        20px;
    cursor:                      inherit;
}

element-text {
    background-color:            transparent;
    text-color:                  inherit;
    highlight:                   inherit;
    cursor:                      inherit;
    vertical-align:              0.5;
    horizontal-align:            0.0;
    font:                        "JetBrains Mono 10";
}

/*****----- Mode Switcher -----*****/
mode-switcher {
    enabled:                     true;
    spacing:                     10px;
    margin:                      0px;
    padding:                     0px;
    border:                      0px solid;
    border-radius:               0px;
    border-color:                @border-colour;
    background-color:            @transparent;
    text-color:                  @foreground-colour;
}

button {
    padding:                     8px 12px;
    border:                      0px solid;
    border-radius:               6px;
    border-color:                @border-colour;
    background-color:            @alternate-background;
    text-color:                  @foreground-colour;
    cursor:                      pointer;
}

button selected {
    background-color:            @selected-normal-background;
    text-color:                  @selected-normal-foreground;
}
"""
    
    def copy_to_clipboard(self, text: str) -> bool:
        """Copy text to clipboard using multiple methods"""
        methods = [
            # Try wl-copy first (Wayland)
            lambda: subprocess.run(['wl-copy'], input=text, text=True, check=True, timeout=5),
            # Then xclip (X11)
            lambda: subprocess.run(['xclip', '-selection', 'clipboard'], input=text, text=True, check=True, timeout=5),
            # Then xsel (X11 alternative)  
            lambda: subprocess.run(['xsel', '--clipboard', '--input'], input=text, text=True, check=True, timeout=5),
        ]
        
        for method in methods:
            try:
                method()
                return True
            except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                continue
        
        return False
    
    def type_text(self, text: str) -> bool:
        subprocess.run(['xdotool', 'key', 'ctrl+v', text], check=False, timeout=10),
        return True
    
    def run_in_terminal(self, command: str) -> bool:
        """Run command in a new terminal window"""
        # List of terminal emulators to try, in order of preference
        terminals = [
            # Modern terminals with good support
            ['alacritty', '-e', 'bash', '-c'],
            ['kitty', '-e', 'bash', '-c'],
            ['wezterm', 'start', '--', 'bash', '-c'],
            ['foot', '-e', 'bash', '-c'],
            
            # Traditional terminals
            ['gnome-terminal', '--', 'bash', '-c'],
            ['konsole', '-e', 'bash', '-c'],
            ['xterm', '-e', 'bash', '-c'],
            ['urxvt', '-e', 'bash', '-c'],
            ['st', '-e', 'bash', '-c'],
            
            # Fallback
            ['x-terminal-emulator', '-e', 'bash', '-c'],
        ]
        
        # Create a command that runs the history command and keeps terminal open
        full_command = f'{command}; echo ""; echo "Press Enter to close..."; read'
        
        for term_cmd in terminals:
            try:
                subprocess.Popen(term_cmd + [full_command], 
                               stdout=subprocess.DEVNULL, 
                               stderr=subprocess.DEVNULL)
                return True
            except FileNotFoundError:
                continue
        
        # If no terminal found, try with shell detection
        shell = os.environ.get('SHELL', 'bash')
        shell_name = shell.split('/')[-1]
        
        for term_cmd in terminals[:5]:  # Try only the modern ones
            try:
                cmd = term_cmd[:-2] + [shell_name, '-c'] 
                subprocess.Popen(cmd + [full_command],
                               stdout=subprocess.DEVNULL, 
                               stderr=subprocess.DEVNULL)
                return True
            except FileNotFoundError:
                continue
                
        return False
    
    def edit_command(self, command: str) -> Optional[str]:
        """Edit command in nvim"""
        editor = 'nvim'  # Force nvim as requested
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
            f.write(command)
            temp_file = f.name
        
        try:
            # Open in terminal with nvim
            terminal_cmd = None
            terminals = [
                ['alacritty', '-e'],
                ['kitty', '-e'], 
                ['wezterm', '-e'],
                ['foot', '-e'],
                ['gnome-terminal', '--'],
                ['konsole', '-e'],
                ['xterm', '-e'],
            ]
            
            for term_cmd in terminals:
                try:
                    subprocess.run(term_cmd + [editor, temp_file], check=True, timeout=120)
                    terminal_cmd = term_cmd
                    break
                except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
                    continue
            
            if not terminal_cmd:
                # Fallback to direct nvim call
                try:
                    subprocess.run([editor, temp_file], timeout=120)
                except subprocess.TimeoutExpired:
                    pass
            
            # Read the edited content
            with open(temp_file, 'r') as f:
                edited_command = f.read().strip()
            
            return edited_command if edited_command != command else None
            
        except Exception as e:
            self.history_manager.show_error(f"Error editing command: {e}")
            return None
        finally:
            # Clean up temp file
            try:
                os.unlink(temp_file)
            except:
                pass
    
    def show_help(self) -> str:
        """Return help message"""
        help_text = """Enter: Obvious | Alt+E: Edit | Alt+Return: Run | Alt+C: Copy | Esc: Exit""".strip()
        return help_text
    
    def run(self) -> int:
        """Run the Rofi history menu"""
        if not self.history_manager.load_history():
            return 1
        
        if not self.history_manager.commands:
            self.history_manager.show_error("No commands found in history")
            return 1
        
        # Prepare Rofi input
        rofi_input = []
        for cmd in self.history_manager.commands:
            formatted = self.history_manager.format_command_for_rofi(
                cmd, self.show_timestamps, self.show_line_numbers)
            rofi_input.append(formatted)
        
        # Write theme to temp file
        theme_file = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', suffix='.rasi', delete=False) as f:
                f.write(self.get_rofi_theme())
                theme_file = f.name
            
            # Prepare Rofi command
            rofi_cmd = [
                'rofi',
                '-dmenu',
                '-theme', theme_file,
                '-p', '📜 History',
                '-format', 'i',  # Return index
                '-i',  # Case insensitive
                '-markup-rows',
                '-kb-custom-1', 'Alt+e',     # Edit command
                '-kb-custom-2', 'Alt+Return',     # Run in new terminal
                '-kb-custom-3', 'Alt+c',     # Copy only
                '-kb-custom-4', 'F1',        # Help
                '-kb-accept-entry', 'Return',
                '-kb-cancel', 'Escape,Super_L+colon',
                '-lines', '10',
                '-width', '900',
                '-columns', '1',
            ]
            
            # Show help message
            help_msg = self.show_help()
            rofi_cmd.extend(['-mesg', help_msg])
            
            # Run Rofi
            process = subprocess.run(
                rofi_cmd,
                input='\n'.join(rofi_input),
                text=True,
                capture_output=True,
                timeout=300  # 5 minute timeout
            )
            
            if process.returncode == 0:
                # Normal selection - Copy and Type instantly
                try:
                    index = int(process.stdout.strip())
                    selected_command = self.history_manager.commands[index]['command']
                    
                    # Copy to clipboard
                    copy_success = self.copy_to_clipboard(selected_command)
                    
                    type_success = self.type_text(selected_command)
                    
                    if copy_success and type_success:
                        self.history_manager.show_notification("Executed")
                    elif copy_success:
                        self.history_manager.show_notification("Copied")
                    elif type_success:
                        self.history_manager.show_notification("Typed")
                    else:
                        self.history_manager.show_error("❌")
                        
                except (ValueError, IndexError):
                    self.history_manager.show_error("Invalid selection")
                    return 1
                    
            elif process.returncode == 10:
                # Alt+E pressed - Edit mode
                try:
                    index = int(process.stdout.strip()) 
                    selected_command = self.history_manager.commands[index]['command']
                    
                    edited_command = self.edit_command(selected_command)
                    if edited_command:
                        copy_success = self.copy_to_clipboard(edited_command)
                        type_success = self.type_text(edited_command)
                        
                        if copy_success and type_success:
                            self.history_manager.show_notification("Edited, Copied & Typed")
                        else:
                            self.history_manager.show_error("❌")
                            
                except (ValueError, IndexError):
                    self.history_manager.show_error("Invalid selection for editing")
                    return 1
                    
            elif process.returncode == 11:
                # Alt+Return pressed - Run in terminal
                try:
                    index = int(process.stdout.strip())
                    selected_command = self.history_manager.commands[index]['command']
                    
                    if self.run_in_terminal(selected_command):
                        self.history_manager.show_notification("Running in terminal")
                    else:
                        self.history_manager.show_error("❌")
                        
                except (ValueError, IndexError):
                    self.history_manager.show_error("Invalid selection for terminal execution")
                    return 1
                    
            elif process.returncode == 12:
                # Alt+C pressed - Copy only
                try:
                    index = int(process.stdout.strip())
                    selected_command = self.history_manager.commands[index]['command']
                    
                    if self.copy_to_clipboard(selected_command):
                        self.history_manager.show_notification("Copied")
                    else:
                        self.history_manager.show_error("❌")
                        
                except (ValueError, IndexError):
                    self.history_manager.show_error("Invalid selection")
                    return 1
                    
            elif process.returncode == 13:
                # F1 pressed - Show help (already shown in mesg)
                return self.run()  # Restart to show help
                
            else:
                # User cancelled or error
                return process.returncode if process.returncode != 1 else 0
                
        except subprocess.TimeoutExpired:
            self.history_manager.show_error("Operation timed out")
            return 1
        except Exception as e:
            self.history_manager.show_error(f"Unexpected error: {e}")
            return 1
        finally:
            # Clean up theme file
            if theme_file:
                try:
                    os.unlink(theme_file)
                except:
                    pass
        
        return 0

def main():
    parser = argparse.ArgumentParser(
        description='🚀 Rofi Terminal History Menu - Beautiful history browser with instant actions',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    # Launch with timestamps and line numbers
  %(prog)s --no-timestamps    # Hide timestamps
  %(prog)s --no-line-numbers  # Hide line numbers
  %(prog)s --edit-mode        # Start in edit mode

Keyboard Shortcuts:
  ENTER         Copy to clipboard + Type instantly
  Alt+E         Edit command in nvim
  Alt+Enter     Run in new terminal window
  Alt+C         Copy to clipboard only
  F1            Show help
  Escape        Cancel and exit
        """
    )
    
    parser.add_argument('--no-timestamps', action='store_true', 
                       help='Hide timestamps in command list')
    parser.add_argument('--no-line-numbers', action='store_true',
                       help='Hide line numbers in command list')
    parser.add_argument('--edit-mode', action='store_true', 
                       help='Start in edit mode (for power users)')
    parser.add_argument('--version', action='version', version='%(prog)s 2.0')
    
    args = parser.parse_args()
    
    menu = RofiHistoryMenu(
        show_timestamps=not args.no_timestamps,
        show_line_numbers=not args.no_line_numbers,
        edit_mode=args.edit_mode
    )
    
    return menu.run()

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n🚫 Cancelled by user")
        sys.exit(130)
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        sys.exit(1)
