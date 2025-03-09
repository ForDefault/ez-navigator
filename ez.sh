#!/bin/bash

# Color Definitions and Command Substitutions
RED='\033[0;31m'
GREEN='\033[0;32m'
NEON_RED='\033[1;31m'
NEON_GREEN='\033[1;32m'
NEON_BLUE='\033[1;36m'
NEON_YELLOW='\033[1;33m'
NEON_RED="\033[1;31m"        # Bright red
NEON_YELLOW_BG="\033[1;43m" # Bright yellow background
NEON_BLACK="\033[30m"       # Black text
NC='\033[0m' # No Color
COLWIDTH=40
cd2cd=""
LAST_PATH_KEY=""
BOOKMARK_LIST=()  # List to store multiple bookmarks
CURRENT_DIR=$(pwd)
tab=$('\t')  # Proper tab setting
MODE="navigation"  # Flag to track the current mode
selected_item=""  # Track the selected file or directory
current_selection=0  # Track the current selected item in the list
tab_screen=$'\t'  # Proper tab setting for screen command

####################
# Substitute Values
####################
TERM_WIDTH=$(tput cols)        # Terminal width
TERM_PAD=5                     # General terminal padding
COL_PAD=6                      # Column padding for spacing
MAX_DISPLAY_LENGTH=40          # Maximum display length for trimming filenames
BORDER_CHAR="-"                # Character for horizontal borders
INDEX_OFFSET=0                 # Offset for numbering starting at 1
####################
B=$"#Bookmark for Option to be added"
# Print prompt at the top of the display
activeuser=$(whoami)
ez_folder="/home/$activeuser/.ez_navigator"
non_user_screenstxt="$ez_folder/non_user_screenstxt.txt"
users_screenstxt="$ez_folder/users_screens.txt"
temp_screen_diff="$ez_folder/temp_screen_diff.txt"
temp_file="$ez_folder/temp_users_screens.txt"
mkdir -p $ez_folder
touch "$non_user_screenstxt" "$users_screenstxt" "$temp_screen_diff" "$temp_file"
highlight_text() {
    local text="$1"  # Takes any text input
    echo -e "\033[1;47m\033[30m${text}${NC}"  # White background with Black text
}
highlight_terminated() {
    local text="$1"  # Takes any text input
    echo -e "\033[1;41m\033[97m${text}${NC}"  # Rose Red background with Bright White text
}
warning_highlight() {
    local text="$1"  # Takes any text input
    echo -e "\033[1;43m\033[30m${text}${NC}"  # Bright Yellow background with Black text
}

print_prompt() {
    echo "Select a number, press = to go to the last directory, Backspace for '..', \\ twice to bookmark, ! for Clipboard Manager, Tab to enter Terminal Mode:"
#Bookmark list not yet working
    if [[ -n "$LAST_PATH_KEY" ]]; then
        echo -e "Last Directory: ${NEON_BLUE}$LAST_PATH_KEY${NC}"
    fi

    if [[ ${#BOOKMARK_LIST[@]} -gt 0 ]]; then
        echo -e "${NEON_YELLOW}Bookmarks:${NC}"
        for bookmark in "${BOOKMARK_LIST[@]}"; do
            echo -e "${NEON_YELLOW}$bookmark${NC}"
        done
    fi
}
track_directory() {
    LAST_PATH_KEY="$CURRENT_DIR"  # Save current directory to LAST_PATH_KEY
    CURRENT_DIR=$(pwd)            # Update CURRENT_DIR to the new directory
}

# Function to handle directory and file navigation choices
handle_choice() {
    local choice="$1"
    local main_choice
    local sub_choice

    main_choice=$(echo "$choice" | cut -d'.' -f1)
    sub_choice=$(echo "$choice" | cut -d'.' -f2)

    if [[ "$main_choice" == "=" ]]; then
        if [[ -n "$LAST_PATH_KEY" ]]; then
            cd "$LAST_PATH_KEY"  # Move to the last visited directory
            echo "Navigated to LAST_PATH_KEY: $LAST_PATH_KEY"
        else
            echo "No last directory to return to."
        fi
    elif [[ "$main_choice" == "==" ]]; then
        if [[ -n "$cd2cd" ]]; then
            LAST_PATH_KEY=$(pwd)
            cd "$cd2cd"
            cd2cd=""
        else
            echo "No previous directory to return to."
        fi
    elif [[ "$main_choice" == "BS" ]]; then
        LAST_PATH_KEY=$(pwd)
        cd2cd=$(pwd)
        echo "cd2cd set to: $cd2cd"
        cd ..
    elif [[ "$main_choice" == "\\\\" ]]; then
        if [[ "$choice" == "\\\\" ]]; then
            BOOKMARK_LIST+=("$(pwd)")
            echo "Directory bookmarked: $(pwd)"
        fi
    elif [[ "$main_choice" -gt 0 && "$main_choice" -le $((dir_count + file_count)) ]]; then
        if [[ "$main_choice" -le $dir_count ]]; then
            selected_item="${dirs[$main_choice]}"  # Use correct indexing (starts at 1)
            cd "$selected_item"
            refresh_to_pseudo
            echo "Moved to $selected_item"
        else
            file_index=$((main_choice - dir_count))  # Adjust file index correctly
            selected_item="${files[$file_index]}"
            echo "File selected: $selected_item"
            echo "1) Cat output and to clipboard"
            echo "2) Filename + copy content to clipboard"
            echo "3) Edit with nano"
            echo "4) Extract with tar"
            echo "5) Display and copy ls -la output to clipboard"
            echo "6) Delete (confirm before delete)"
            echo "0) Exit"
            read -p "Choose an option: " file_action
            handle_file_action "$file_action"
        fi
    else
        echo "Invalid selection."
    fi
}


# Function to handle file actions
handle_file_action() {
    local file_action="$1"
    case $file_action in
        1)
            xclip -selection clipboard < "$selected_item"
            echo "Content copied to clipboard."
            ;;
        2)
            {
                echo "$selected_item"
                echo "================="
                cat "$selected_item"
            } | xclip -selection clipboard
            echo "Filename and content copied to clipboard."
            ;;
        3)
            nano "$selected_item"
            ;;
        4)
            tar -xvf "$selected_item"
            ;;
        5)
            ls -la | xclip -selection clipboard
            ls -la
            echo "ls -la output copied to clipboard."
            ;;
        6)
            read -p "Are you sure you want to delete $selected_item? (y/n): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                rm "$selected_item"
                echo "$selected_item deleted."
            else
                echo "Deletion canceled."
            fi
            ;;
        0)
            return 0
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# Clipboard Manager Menu
clipboard_manager() {
    while true; do
        clear
        echo "Clipboard Manager:"
        echo "1) View clipboard content"
        echo "2) Clear clipboard"
        echo "3) Press ! to return to the main menu"
        read -p "Choose an option: " clipboard_choice
        case "$clipboard_choice" in
            1)
                echo "Clipboard content:"
                xclip -o -selection clipboard
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            2)
                echo -n "" | xclip -selection clipboard
                echo "Clipboard cleared."
                read -n 1 -s -r -p "Press any key to return..."
                ;;
            3)
                refresh_to_pseudo  # Refresh to the main menu
                return
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    done
}


# Function to search current directory
search_current_directory() {
    read -p "Enter search query (e.g., 'dog food, cat -snake'): " search_query

    IFS=',' read -r -a search_terms <<< "$search_query"

    include_terms=()
    exclude_terms=()

    for term in "${search_terms[@]}"; do
        if [[ $term == -* ]]; then
            exclude_terms+=("${term:1}")
        else
            include_terms+=("$term")
        fi
    done

    grep_command="grep -ril"
    for term in "${include_terms[@]}"; do
        grep_command+=" -e \"$term\""
    done
    for term in "${exclude_terms[@]}"]; do
        grep_command+=" --exclude-dir=* -v -e \"$term\""
    done

    mapfile -t search_results < <(eval $grep_command .)

    if [ ${#search_results[@]} -eq 0 ]; then
        echo "No matching files found."
    else
        echo "Search completed. ${#search_results[@]} files found."
        display_search_results
    fi
}

# Function to display search results with options
display_search_results() {
    while true; do
        clear
        echo "Search Results:"
        for i in "${!search_results[@]}"; do
            printf "${NEON_GREEN}%2d. %s${NC}\n" $((i + 1)) "${search_results[i]}"
        done

        echo "0) Search options menu"
        echo "1) Narrow search within results"
        echo "2) Copy names of searched files (full path)"
        echo "3) Output names to search_results.txt"
        echo "4) Go back"

        read -n 1 -s -p "Choose an option: " result_action

        case $result_action in
            0) search_options_menu ;;
            1) search_within_results ;;
            2) copy_search_results ;;
            3) output_search_results ;;
            4) return ;;
            *) echo "Invalid option." ;;
        esac
    done
}

# Function to handle the sub search menu (option 0)
search_options_menu() {
    while true; do
        clear
        echo -e "${NEON_YELLOW}--- Search Options Menu ---${NC}"
        echo "1) Search from results list"
        echo "2) Copy names of searched files (full path)"
        echo "3) Output names to search_results.txt"
        echo "4) Go back"

        read -n 1 -s -p "Choose an option: " search_option

        case $search_option in
            1) search_within_results ;;
            2) copy_search_results ;;
            3) output_search_results ;;
            4) return ;;
            *) echo "Invalid option." ;;
        esac
    done
}

#Function to narrow the search within the results (option 1)
search_within_results() {
    narrowed_results=()
    read -p "Enter additional search query: " additional_query

    for file in "${search_results[@]}"; do
        if grep -q "$additional_query" "$file"; then
            narrowed_results+=("$file")
        fi
    done

    if [ ${#narrowed_results[@]} -eq 0 ]; then
        echo "No further matches found."
    else
        search_results=("${narrowed_results[@]}")
        echo "Narrowed search completed. ${#search_results[@]} files remaining."
        display_search_results
    fi
}

# Function to copy search result filenames with full paths to clipboard (option 2)
copy_search_results() {
    echo "${search_results[@]}" | tr ' ' '\n' | xclip -selection clipboard
    echo "Searched filenames copied to clipboard."
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to output search result filenames to search_results.txt (option 3)
output_search_results() {
    echo "${search_results[@]}" | tr ' ' '\n' > search_results.txt
    echo "Searched filenames saved to search_results.txt."
    read -n 1 -s -r -p "Press any key to continue..."
}

display_items_fileNav() {
    NC=$'\e[m'; RED=$'\e[91m'; GREEN=$'\e[92m'
    dir_count=0
    file_count=0
    max_items=0
    term_width=$(tput cols)
    col_width=$(( (term_width / 2) - 5 )) # Adjust column width
    max_display_length=$(( col_width - 6 ))

    # Function to trim strings to fit the display
    trim_string() {
        local str="$1"
        local len=${#str}
        if (( len > max_display_length )); then
            echo "...${str: -$((max_display_length - 3))}"  # Trim with ellipsis
        else
            echo "$str"
        fi
    }

    # Function to draw a horizontal border
    draw_border() {
        printf '%*s\n' "$term_width" '' | tr ' ' '-'
    }

    # Function to identify and format symlinks
    for_mapfiles() {
        format_symlink() {
            local filepath="$1"
            if [[ -L "$filepath" ]]; then
                echo "(SYSLINK) ${filepath##*/}"  # Display only the symlink name
            else
                echo "${filepath##*/}"
            fi
        }

        # List directories (including hidden ones) and sort
        mapfile -t dirs < <(
            find . -maxdepth 1 -mindepth 1 -type d ! -name '.' ! -name '..' -printf '%p\n' |
            sort
        )

        # List files (including hidden ones and symlinks to files) and sort
        mapfile -t files < <(
            find . -maxdepth 1 -mindepth 1 \( -type f -o -type l \) -printf '%p\n' |
            sort
        )

        formatted_dirs=()
        formatted_files=()

        for dir in "${dirs[@]}"; do
            formatted_dirs+=("$(format_symlink "$dir")")
        done

        for file in "${files[@]}"; do
            formatted_files+=("$(format_symlink "$file")")
        done
    }

    # Call for_mapfiles to populate directories and files
    for_mapfiles

    dir_count=${#formatted_dirs[@]}
    file_count=${#formatted_files[@]}
    max_items=$(( dir_count > file_count ? dir_count : file_count ))

    # Build the output with bottom-up order and dynamic spacing
    output=""
    for (( i = max_items; i >= 1; i-- )); do
        # Left Column: Files (numbering starts after directories)
        if (( i <= file_count )); then
            trimmed_file=$(trim_string "${formatted_files[$((i - 1))]}")
            output+=$(printf "${GREEN}%2d. %-*s${NC}" $((dir_count + i)) "$col_width" "$trimmed_file")
        else
            output+=$(printf "%-*s" "$col_width" "")
        fi

        # Right Column: Directories (normal numbering)
        if (( i <= dir_count )); then
            trimmed_dir=$(trim_string "${formatted_dirs[$((i - 1))]}")
            output+=$(printf "${RED}%2d. %-*s${NC}" $i "$col_width" "$trimmed_dir")
        fi

        output+=$'\n'
    done

    # Print everything with borders and aligned titles
    draw_border
    echo "$output"
    printf "${GREEN}%-*s${NC}${RED}%-*s${NC}\n" "$col_width" "Files:" "$col_width" "Directories:"
    draw_border
}

navigation_numbers() {
    local choice="$1"  # Start with the initial number passed from the earlier selection

    # Start color in yellow for numbers
    tput setaf 3

    # Loop to capture additional multi-digit input (up to 4 digits)
    while true; do
        read -n 1 -s input_char  # Silent mode to capture the input

        # Check for Backspace input
        if [[ "$input_char" == $'\x7f' ]]; then
            # If backspace, remove the last character from choice
            choice=${choice%?}
            echo -ne "\033[1D \033[1D"  # Move cursor back and clear the character on screen
        elif [[ "$input_char" =~ [0-9] ]]; then
            # Append the number to the choice string
            choice+="$input_char"
            echo -n "$input_char"  # Echo the number to show it in the terminal
        else
            # If input is not a number, break (e.g., Enter key or invalid input)
            break
        fi

        # Limit to 4 digits
        if [[ ${#choice} -ge 4 ]]; then
            break
        fi
    done

    tput setaf 7  # Reset color to white

    # Call the file navigation function with the collected number
    collect_items_fileNav "$choice"
}
####################
# Screen Commands
####################

check_users_screens() {
    generate_users_screens
    # Ensure users_screens.txt exists or create it
    if [ ! -f "$users_screenstxt" ]; then
        echo "Creating $users_screenstxt..."
        > "$users_screenstxt"  # Initialize an empty file
    fi

    echo "Checking and updating $users_screenstxt with active screens..."

    # Get all active screens from screen -ls
    screen -ls | grep -oP '^\s*[0-9]+\.\S+' > "$temp_file"

    # Filter users_screens.txt to keep only active screens
    if [ -s "$temp_file" ]; then
        grep -vFf "$users_screenstxt" "$non_user_screenstxt" | sed '/^$/d' > "$temp_file"
        grep -vFf "$temp_file" "$non_user_screenstxt" | sed '/^$/d' > "$users_screenstxt"

        mv "$non_user_screenstxt" "$users_screenstxt"

        echo "Updated $users_screenstxt with only active screens."
    else
        echo "No active screens found. $users_screenstxt not updated."
    fi

    # Cleanup temporary file
    rm -f "$temp_file"
}



generate_users_screens() {
    rm $non_user_screenstxt
    # Ensure users_screens.txt exists
    if [ ! -f "$users_screenstxt" ]; then
        echo "Creating $users_screenstxt..."
        > "$users_screenstxt"  # Initialize an empty file
    fi

    echo "Processing and updating users_screens.txt..."

    # Get all active screens from screen -ls
    screen -ls | grep -oP '^\s*[0-9]+\.\S+' > "$temp_file"

    # Filter out user screens from the active screens
    if [ -s "$temp_file" ]; then
        grep -vFf "$users_screenstxt" "$temp_file" | sed '/^$/d' > "$non_user_screenstxt"
        echo "Non-user screens saved to $non_user_screenstxt."
    else
        echo "No active screens found. Non-user screen list not updated."
    fi

    # Cleanup temporary file
    rm -f "$temp_file"
}
remove_screen_user() {
    local screen_name="$1"

    if [[ -n "$screen_name" ]]; then
        # Highlight the screen name
        local highlighted_name
        highlighted_name=$(highlight_text "$screen_name")

        echo "Attempting to remove screen: $highlighted_name"
        full_session_name=$(screen -ls | grep -o "[0-9]*\.${screen_name}" | xargs)

        if [[ -z "$full_session_name" ]]; then
            local highlighted_full_session
            highlighted_full_session=$(highlight_text "$screen_name")
            echo "$(warning_highlight "Screen session matching '$highlighted_full_session' not found.")"
            generate_users_screens  # Regenerate lists in case of mismatch
            return
        fi

        # Highlight full session name
        local highlighted_full_session
        highlighted_full_session=$(highlight_text "$full_session_name")

        # Attempt to terminate the screen session
        screen -S "$full_session_name" -X quit
        if [ $? -eq 0 ]; then
            echo "Screen session '$highlighted_full_session' $(highlight_terminated "terminated")."
            sed -i "/^${screen_name}$/d" "$users_screenstxt"  # Remove from users_screens.txt
        else
            echo "$(warning_highlight "Failed to terminate screen session '$highlighted_full_session'.")"
        fi
    else
        echo "$(warning_highlight "No screen_name provided. Updating lists instead.")"
    fi
    generate_users_screens
}

remove_screen_non_user() {
    local screen_name="$1"

    if [[ -n "$screen_name" ]]; then
        # Highlight the screen name
        local highlighted_name
        highlighted_name=$(highlight_text "$screen_name")

        echo "Attempting to remove non-user screen: $highlighted_name"

        # Verify the screen exists in the non_user_screenstxt file
        if ! grep -q "^${screen_name}$" "$non_user_screenstxt"; then
            echo "$(warning_highlight "Screen session '$highlighted_name' not found in the list.")"
            return
        fi

        # Extract the full session name from screen -ls using the file entry
        full_session_name=$(screen -ls | awk -v name="$screen_name" '$0 ~ name {print $1}' | xargs)

        if [[ -z "$full_session_name" ]]; then
            echo "$(warning_highlight "Screen session matching '$highlighted_name' not found in active sessions.")"
            return
        fi

        # Highlight the full session name
        local highlighted_full_session
        highlighted_full_session=$(highlight_text "$full_session_name")

        # Attempt to terminate the screen session
        screen -S "$full_session_name" -X quit
        if [ $? -eq 0 ]; then
            echo "Screen session '$highlighted_full_session' $(highlight_terminated "terminated")."
            # Safely remove the entry from non_user_screenstxt
            grep -v "^${screen_name}$" "$non_user_screenstxt" > "${non_user_screenstxt}.tmp"
            mv "${non_user_screenstxt}.tmp" "$non_user_screenstxt"
        else
            echo "$(warning_highlight "Failed to terminate screen session '$highlighted_full_session'.")"
        fi
    else
        echo "$(warning_highlight "No screen_name provided.")"
    fi
}


add_screen() {
    # Prompt the user for a name or use a default
    read -p "Enter a name for the screen session (or press Enter for default): " userdefined
    default_name="my_predefined_screen"

    # Use the user-provided name or fall back to the default
    base_name="${userdefined:-$default_name}"
    counter=0
    unique_name="${base_name}"

    # Check for existing screen sessions and increment the name if needed
    while screen -ls | grep -q "${unique_name}"; do
        counter=$((counter + 1))
        unique_name="${base_name}_${counter}"
    done

    # Append the unique name to the file
    echo "${unique_name}" >> "$users_screenstxt"

    # Create a detached screen session with the unique name
    screen -dmS "$unique_name"
    echo "Screen session $(highlight_text "$unique_name") created and appended to users_screens.txt."
    generate_users_screens
}

submenu_for_user_screen() {
    local selected_screen="$1"
    # Highlight the selected screen
    local highlighted_screen
    highlighted_screen=$(highlight_text "$selected_screen")

    echo -e "\n${NEON_GREEN}Options for User Screen: ${NC}${highlighted_screen}"
    echo "1) Reattach to screen"
    echo "2) Delete screen"
    echo "q) Go back to screen manager"
    echo ""

    while true; do
        read -p "Choose an action: " submenu_choice

        case "$submenu_choice" in
            1)
                echo "Reattaching to screen: $highlighted_screen"
                if screen -r "$selected_screen"; then
                    echo "Successfully reattached to $highlighted_screen."
                else
                    echo "$(warning_highlight "Failed to reattach. Screen might not exist.")"
                fi
                break
                ;;
            2)
                # Use remove_screen_user to handle deletion
                remove_screen_user "$selected_screen"
                break
                ;;
            q)
                echo "Returning to screen manager menu."
                break
                ;;
            *)
                echo "$(warning_highlight "Invalid choice. Please try again.")"
                ;;
        esac
    done
}

submenu_for_non_user_screen() {
    local selected_screen="$1"
    # Highlight the selected screen
    local highlighted_screen
    highlighted_screen=$(highlight_text "$selected_screen")

    echo -e "\n${NEON_RED}Options for Non-User Screen: ${NC}${highlighted_screen}"
    echo "1) Reattach to screen"
    echo "2) Delete screen"
    echo "q) Go back to screen manager"
    echo ""

    while true; do
        read -p "Choose an action: " submenu_choice

        case "$submenu_choice" in
            1)
                echo "Reattaching to screen: $highlighted_screen"
                if screen -r "$selected_screen"; then
                    echo "Successfully reattached to $highlighted_screen."
                else
                    echo "$(warning_highlight "Failed to reattach. Screen might not exist.")"
                fi
                break
                ;;
            2)
                # Use remove_screen_non_user to handle deletion
                remove_screen_non_user "$selected_screen"
                break
                ;;
            q)
                screen_manager_menu
                break
                ;;
            *)
                echo "$(warning_highlight "Invalid choice. Please try again.")"
                ;;
        esac
    done
}


screen_manager_menu() {
    check_users_screens
    # Refresh lists before display
    generate_users_screens

    while true; do
        clear
        echo ""
        echo "1) Create a new screen"
        echo "q) Quit"
        echo ""
        echo -e "${NEON_GREEN} ============================================================${NC}"
        echo ""  # Add a newline for better formatting

        local counter=1
        local user_screen_count=0

        # Display user screens
        if [ -s "$users_screenstxt" ]; then
            while IFS= read -r line; do
                printf "   %d) %s\n" "$counter" "$line"
                counter=$((counter + 1))
                user_screen_count=$((user_screen_count + 1))
            done < "$users_screenstxt"
        else
            echo "                     No other screens found."
        fi
        echo ""  # Add a newline for better formatting

        echo -e "${NEON_GREEN} ================↑↑↑ USER SCREEN SESSIONS ↑↑↑================${NC}"
        echo -e "${NEON_RED} ================↓↓↓ ALL  OTHER  SCREENS  ↓↓↓================${NC}"
        echo ""  # Add a newline for better formatting

        # Capture the starting counter for non-user screens
        local non_user_start=$counter

        # Display non-user screens
        if [ -s "$non_user_screenstxt" ]; then
            while IFS= read -r line; do
                printf "   %d) %s\n" "$counter" "$line"
                counter=$((counter + 1))
            done < "$non_user_screenstxt"
        else
            echo "                     No other screens found."
        fi
        echo ""  # Add a newline for better formatting
        echo -e "${NEON_RED} ============================================================${NC}"
        echo ""  # Add a newline for better formatting

        # Prompt for input
        read -p "Enter screen number, Backspace to go back, or 'q' to quit: " choice
        echo ""  # Add a newline for better formatting

        # Process input
        case "$choice" in
            0)
                add_screen
                ;;
            $| $'\x7f' | '=' | 0)  # Backspace, =, and 0 to exit to pseudo display
                MODE="navigation"  # Return to Navigation Mode
                refresh_to_pseudo
                break
                ;;
            q)
                MODE="navigation"
                refresh_to_pseudo
                break
                ;;
            *)
                if [[ "$choice" =~ ^[1-9][0-9]*$ ]]; then
                    local main_choice="$choice"
                    local selected_screen=""

                    if (( main_choice < non_user_start )); then
                        # User screen range
                        selected_screen=$(sed -n "${main_choice}p" "$users_screenstxt")
                        if [[ -n "$selected_screen" ]]; then
                            submenu_for_user_screen "$selected_screen"
                        else
                            echo "Invalid selection. Please try again."
                        fi
                    else
                        # Non-user screen range
                        local offset=$((main_choice - non_user_start + 1))
                        selected_screen=$(sed -n "${offset}p" "$non_user_screenstxt")
                        if [[ -n "$selected_screen" ]]; then
                            submenu_for_non_user_screen "$selected_screen"
                        else
                            echo "Invalid selection. Please try again."
                        fi
                    fi
                else
                    echo "Invalid input. Please try again."
                fi
                ;;
        esac
        read -n 1 -s -p "Press any key to continue..."
    done
}



reattach_screen() {
    local screen_name="$1"
    echo "Reattaching to screen: $screen_name"
    screen -r "$screen_name"
}
####################
#Terminal Mode
####################


TERMINAL_SCREEN_SESSION="terminal_mode"

toggle_terminal_mode() {
    # Check if the session exists
    if screen -ls | grep -q "$TERMINAL_SCREEN_SESSION"; then
        # Check if we are inside the session
        if [[ "$STY" == "$TERMINAL_SCREEN_SESSION" ]]; then
            # Suppress detach message
            stty -echo                       # Disable terminal output
            screen -X detach > /dev/null 2>&1
            stty echo                        # Re-enable terminal output
        else
            # Suppress reattach message
            stty -echo                       # Disable terminal output
            screen -r "$TERMINAL_SCREEN_SESSION" > /dev/null 2>&1
            stty echo                        # Re-enable terminal output
        fi
    else
        # Create a new session quietly
        local temp_config
        temp_config=$(mktemp)
        echo 'bindkey ^I detach' > "$temp_config"
        stty -echo                           # Disable terminal output
        screen -dmS "$TERMINAL_SCREEN_SESSION" -c "$temp_config" > /dev/null 2>&1
        stty echo                            # Re-enable terminal output
        rm -f "$temp_config"

        # Reattach to the session silently
        stty -echo                           # Disable terminal output
        screen -r "$TERMINAL_SCREEN_SESSION" > /dev/null 2>&1
        stty echo                            # Re-enable terminal output
    fi

    # Refresh the pseudo display
    refresh_to_pseudo
}

create_and_run_screen() {
    # Launch a new terminal and start the screen session with Tab binding
    gnome-terminal -- bash -c "
        # Create a temporary screen configuration with Tab-to-detach
        temp_config=\$(mktemp)
        echo 'bindkey ^I detach' > \"\$temp_config\"

        # Start the screen session using the temporary configuration
        stty -echo                           # Disable terminal output
        screen -S \"$TERMINAL_SCREEN_SESSION\" -c \"\$temp_config\"
        stty echo                            # Re-enable terminal output

        # Clean up the temporary configuration file
        rm -f \"\$temp_config\"
    "
}




####################
# Active Reader for navigation input
####################

active_reader() {
    while true; do
        # Default text color
        tput setaf 7  # White color

        read -p "Enter your choice: " -n 1 choice

        case "$choice" in
            0)
                clear
                MODE="menu"
                screen_manager_menu
                ;;
            $'\x7f')  # Handle Backspace
                echo -ne "\033[1A\033[K"
                track_directory
                cd ..
                refresh_to_pseudo
                ;;
            '!')
                if [ "$MODE" != "terminal" ]; then
                    clipboard_manager
                fi
                ;;
            '=')
                handle_choice_fileNav "="  # Use `=` for last_path_key
                ;;
            $tab)  # Handle Tab for Terminal Mode Toggle
                if [ "$MODE" == "navigation" ]; then
                    toggle_terminal_mode
                else
                    toggle_terminal_mode
                fi
                ;;
            $'\e[A')  # Up Arrow Key
                if [ $current_selection -gt 1 ]; then
                    current_selection=$((current_selection - 1))
                fi
                refresh_to_pseudo
                ;;
            [1-9])  # Trigger the navigation number handler for 1-9 input
                initial_choice="$choice"  # Store the first number pressed
                navigation_numbers "$initial_choice"  # Pass it along to the function
                break
                ;;
            *)
                echo -ne "\033[1A\033[K"  # Clear invalid input and refresh pseudo display
                echo "Invalid input, please try again."
                refresh_to_pseudo
                ;;
        esac
    done
}

# Real Input Function to Collect Items
collect_items_fileNav() {
    choice=$1
    final_enter=$2
    handle_choice_fileNav "$choice" "$final_enter"$'\n'
}
handle_choice_fileNav() {
    local choice="$1"

    if [[ "$choice" == "=" ]]; then
        # Return to the last manually visited directory
        if [[ -n "$LAST_PATH_KEY" ]]; then
            cd2cd=$(pwd)  # Save current directory before moving
            cd "$LAST_PATH_KEY"
            echo "Navigated to LAST_PATH_KEY: $LAST_PATH_KEY"
            refresh_to_pseudo
        else
            echo "No last directory to return to."
        fi
    elif [[ "$choice" == "&^%*$" ]]; then
        # Handle custom symbol for returning to the previous directory
        LAST_PATH_KEY=$(pwd)  # Save current directory before moving
        cd2cd=$(pwd)
        echo "cd2cd set to: $cd2cd"
        cd ..
        refresh_to_pseudo
    elif [[ "$choice" -gt 0 && "$choice" -le $((dir_count + file_count)) ]]; then
        # Calculate the total list size
        list_total=$((dir_count + file_count))

        if [[ "$choice" -le $dir_count ]]; then
            # Directory selection
            selected_item="${dirs[$((choice - 1))]}"  # Correct 1-based indexing
            LAST_PATH_KEY=$(pwd)
            cd "$selected_item"
            echo "Moved to directory: $selected_item"
            refresh_to_pseudo
        elif [[ "$choice" -gt $dir_count && "$choice" -le $list_total ]]; then
            # File selection
            file_index=$((choice - dir_count))  # Adjust file index correctly
            selected_item="${files[$((file_index - 1))]}"  # Subtract 1 for 0-based array indexing
            echo "File selected: $selected_item"
            MODE="file_action"  # Switch to file action mode
            file_action_menu  # Invoke the menu for file actions
        else
            echo "Invalid selection."
            refresh_to_pseudo
        fi
    else
        # Handle invalid selections
        echo "Invalid selection."
        refresh_to_pseudo  # Refresh the pseudo display on invalid selection
    fi
}



# File Action Menu to perform actions on selected files
file_action_menu() {
    while true; do
        clear
        echo "File Action Menu:"
        echo "Selected file: $selected_item"
        echo "1) Copy content to clipboard"
        echo "2) Search within current directory"
        echo "3) Edit with nano"
        echo "4) Extract with tar"
        echo "5) Display and copy ls -la output to clipboard"
        echo "6) Delete file"
        echo "backspace) Go back to navigation"

        read -n 1 -s -p "Choose an action: " file_action

        case $file_action in
            1) content_to_clipboard ;;
            2) search_current_directory ;;
            3) edit_with_nano ;;
            4) extract_with_tar ;;
            5) display_and_copy_ls_la ;;
            6) delete_item ;;
            $'\x7f' | '=')  # Backspace, =, and 0 to exit to pseudo display
                MODE="navigation"  # Return to Navigation Mode
                refresh_to_pseudo
                ;;
            *) echo "Invalid option." ;;
        esac
        read -n 1 -s -r -p "Press any key to continue..."
    done
}

# Refresh and return to pseudo display
refresh_to_pseudo() {
    clear
    track_directory
    print_prompt  # Display the prompt at the top
    display_items_fileNav
    active_reader
}

# Custom Action Menu
custom_action_menu() {
    while true; do
        clear
        echo "Custom Action Menu:"
        echo "1) Search current directory"
        echo "2) Display and copy ls -la output to clipboard"
        echo "3) Create a new directory"
        echo "backspace) Go back to navigation"

        read -n 1 -s -p "Choose an option: " menu_choice

        case $menu_choice in
            1) search_current_directory ;;
            2) display_and_copy_ls_la ;;
            3) read -p "Enter directory name: " dir_name
                mkdir "$dir_name"
                echo "Directory '$dir_name' created."
                ;;
            $| $'\x7f' | '=' | 0)  # Backspace, =, and 0 to exit to pseudo display
                MODE="navigation"  # Return to Navigation Mode
                refresh_to_pseudo
                break ;;
            *) echo "Invalid option." ;;
        esac
        read -n 1 -s -r -p "Press any key to continue..."
    done
}

# # Enter Terminal Mode
# enter_terminal_mode() {
#   green="$(tput setaf 2)"
#   red="$(tput setaf 1)"
#   reset="$(tput sgr0)"
#   MODE="terminal"
#   current_dir_tracker=$(pwd)  # Save the current directory
#   clear
#   previous_dir="$current_dir_tracker"

#   while true; do
#     # Display user, hostname, and current directory
#     current_dir=$(pwd)
#     PS1="${green}$(whoami)${reset}@${red}$(pwd)${reset}$ "
#     echo -n "$PS1"

#     # Read the command input or detect Tab without requiring Enter
#     read -n 1 -s cmd  # Read a single character silently
#     if [ "$cmd" == "$tab" ]; then
#       break  # Exit terminal mode
#     else
#       echo -n "$cmd"  # Display the first character
#       read cmd_rest  # Read the rest of the command
#       eval "$cmd$cmd_rest"  # Execute the command using eval
#     fi
#   done
#   exit_terminal_mode
# }

# Exit Terminal Mode and Return to Navigation
exit_terminal_mode() {
  MODE="navigation"
  if [ "$current_dir_tracker" != "$(pwd)" ]; then
    cd2cd=$(pwd)
  fi
  refresh_to_pseudo
}

# Main loop to simulate navigation and terminal mode
while true; do
  if [[ "$MODE" == "navigation" ]]; then
    clear
    print_prompt  # Call the print_prompt function here
    display_items_fileNav
    active_reader
  fi
done
