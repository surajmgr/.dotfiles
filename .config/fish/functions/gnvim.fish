function gnvim
    set godot_dir ~/Games/godot
    
    # Expand tilde to full path
    set godot_dir (eval echo $godot_dir)
    
    # Check if godot directory exists
    if not test -d "$godot_dir"
        echo "❌ Godot directory not found: $godot_dir"
        return 1
    end
    
    # Get list of subdirectories (projects), excluding the godot_dir itself
    set projects (find "$godot_dir" -maxdepth 1 -type d -not -path "$godot_dir" | sort)
    
    # Check if any projects were found
    if test (count $projects) -eq 0
        echo "❌ No projects found in $godot_dir"
        return 1
    end
    
    # Display header
    echo "🎮 Godot Project Selector"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Declare i and valid_projects before the loop
    set -l i 1
    set -l valid_projects
    
    # Display projects with numbers and build valid_projects array
    for project in $projects
        if test -n "$project" -a -d "$project" -a "$project" != "~"
            set project_name (basename "$project" 2>/dev/null)
            if test $status -eq 0
                printf "%2d) %s\n" $i "$project_name"
                set -a valid_projects "$project"
                set i (math $i + 1)
            else
                echo "⚠️ Skipping invalid project path: $project"
                continue
            end
        else
            echo "⚠️ Skipping invalid or empty project path: $project"
            continue
        end
    end
    
    # Check if any valid projects were listed
    if test (count $valid_projects) -eq 0
        echo "❌ No valid projects found"
        return 1
    end
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Declare choice before the loop to avoid block scoping issues
    set -l choice
    
    # Get user choice with validation loop
    while true
        read -P "📂 Select project (1-"(count $valid_projects)" or 'q' to quit): " choice
        
        # Check if user wants to quit
        if test "$choice" = "q" -o "$choice" = "quit"
            echo "👋 Cancelled"
            return 0
        end
        
        # Validate numeric input
        if string match -qr '^\d+$' "$choice"
            if test "$choice" -ge 1 -a "$choice" -le (count $valid_projects)
                break
            end
        end
        
        echo "⚠️ Invalid choice. Please enter a number between 1 and "(count $valid_projects)", or 'q' to quit."
    end
    
    # Select project by iterating to the chosen index
    set -l selected_project
    set i 1
    for project in $valid_projects
        if test -n "$i" -a -n "$choice" -a "$i" -eq "$choice"
            set selected_project "$project"
            break
        end
        set i (math $i + 1)
    end
    
    # Validate selected project
    if test -z "$selected_project" -o ! -d "$selected_project"
        echo "❌ Invalid or missing project directory: $selected_project"
        return 1
    end
    
    set project_name (basename "$selected_project" 2>/dev/null)
    if test $status -ne 0
        echo "❌ Failed to get project name for: $selected_project"
        return 1
    end
    
    echo "✅ Opening project: $project_name"
    echo "📁 Location: $selected_project"
    
    # Change to project directory and start nvim
    if cd "$selected_project"
        echo "🚀 Starting Neovim..."
        nvim --listen 127.0.0.1:55432 .
    else
        echo "❌ Failed to change to project directory: $selected_project"
        return 1
    end
end
