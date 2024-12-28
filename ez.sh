#!/bin/bash

# Color Definitions and Command Substitutions
RED='\033[0;31m'
GREEN='\033[0;32m'
NEON_RED='\033[1;31m'
NEON_GREEN='\033[1;32m'
NEON_BLUE='\033[1;36m'
NEON_YELLOW='\033[1;33m'
NC='\033[0m' # No Color
COLWIDTH=40
cd2cd=""
LAST_PATH_KEY=""
BOOKMARK_LIST=()  # List to store multiple bookmarks
current_dir_tracker=$(pwd)  # Track the current directory
tab=$('\t')  # Proper tab setting
MODE="navigation"  # Flag to track the current mode
selected_item=""  # Track the selected file or directory
current_selection=0  # Track the current selected item in the list

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
print_prompt() {
    echo "Select a number, press = to go to the last directory, Backspace for '..', \\ twice to bookmark, ! for Clipboard Manager, Tab to enter Terminal Mode:"
    if [[ -n "$cd2cd" ]]; then
        echo -e "Previous Directory: ${NEON_BLUE}$cd2cd${NC}"
    fi

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
            LAST_PATH_KEY=$(pwd)  # Set LAST_PATH_KEY before moving to new directory
            selected_item="${dirs[$main_choice]}"  # Use correct indexing (starts at 1)
            cd "$selected_item"
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

# Function to narrow the search within the results (option 1)
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
    dirs=($(ls -d */ 2>/dev/null))
    files=($(ls -p | grep -v /))
    dir_count=${#dirs[@]}
    file_count=${#files[@]}
    max_items=$(( dir_count > file_count ? dir_count : file_count ))
    # Dynamically get terminal size
    term_width=$(tput cols)
    col_width=$(( (TERM_WIDTH / 2) - TERM_PAD ))
    max_display_length=$(( col_width - COL_PAD ))

    # BOOKMARK add option for hidden folders etc. 
        # Collect directories and files (starting from index 1 for ordering)
    # List directories including hidden ones (but not `.` and `..`)
    mapfile -t dirs < <(ls -ld -- */ 2>/dev/null | awk '{print $NF}' | sed 's:/$::' | sort)

    # List files including hidden ones
    mapfile -t files < <(ls -lA -- | grep '^-' | awk '{print $NF}' | sort)



    dir_count=${#dirs[@]}
    file_count=${#files[@]}
    max_lines=$(( file_count > dir_count ? file_count : dir_count ))

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

    # Build the output with bottom-up order and dynamic spacing
    output=""
    for (( i = max_items; i >= 1; i-- )); do
        # Left Column: Files (numbering starts after directories)
        if (( i <= file_count )); then
            trimmed_file=$(trim_string "${files[$((i - 1))]}")  # Correct indexing
            output+=$(printf "${GREEN}%2d. %-*s${NC}" $((dir_count + i)) "$col_width" "$trimmed_file")
        else
            output+=$(printf "%-*s" "$col_width" "")
        fi

        # Right Column: Directories (normal numbering)
        if (( i <= dir_count )); then
            trimmed_dir=$(trim_string "${dirs[$((i - 1))]}")  # Correct indexing
            output+=$(printf "${RED}%2d. %-*s${NC}" $i "$col_width" "$trimmed_dir")
        fi

        output+=$'\n'
    done



    # Print everything with borders and aligned titles
    draw_border
    echo "$output"  # No tac here, output is already reversed
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

# Active Reader for navigation input
active_reader() {
    while true; do
        # Default text color
        tput setaf 7  # White color

        read -p "Enter your choice: " -n 1 choice

        case "$choice" in
            0)
                clear
                MODE="menu"  # Switch to Menu Mode
                custom_action_menu  # Call the custom action menu
                ;;
            $'\x7f')  # Handle Backspace
                echo -ne "\033[1A\033[K"
                cd2cd=$(pwd)
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
                    enter_terminal_mode
                else
                    exit_terminal_mode
                fi
                ;;
            $'\e[A')  # Up Arrow Key
                if [ $current_selection -gt 1 ]; then
                    current_selection=$((current_selection - 1))
                fi
                refresh_to_pseudo
                ;;
            $'\e[B')  # Down Arrow Key
                if [ $current_selection -lt $((dir_count + file_count)) ]; then
                    current_selection=$((current_selection + 1))
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

# Enter Terminal Mode
enter_terminal_mode() {
  green="$(tput setaf 2)"
  red="$(tput setaf 1)"
  reset="$(tput sgr0)"
  MODE="terminal"
  current_dir_tracker=$(pwd)  # Save the current directory
  clear
  previous_dir="$current_dir_tracker"

  while true; do
    # Display user, hostname, and current directory
    current_dir=$(pwd)
    PS1="${green}$(whoami)${reset}@${red}$(pwd)${reset}$ "
    echo -n "$PS1"

    # Read the command input or detect Tab without requiring Enter
    read -n 1 -s cmd  # Read a single character silently
    if [ "$cmd" == "$tab" ]; then
      break  # Exit terminal mode
    else
      echo -n "$cmd"  # Display the first character
      read cmd_rest  # Read the rest of the command
      eval "$cmd$cmd_rest"  # Execute the command using eval
    fi
  done
  exit_terminal_mode
}

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
