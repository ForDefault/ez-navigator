#!/bin/bash

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
NEON_RED='\033[1;31m'
NEON_GREEN='\033[1;32m'
NEON_BLUE='\033[1;36m'
NEON_YELLOW='\033[1;33m'
NC='\033[0m' # No Color
COLWIDTH=40
PREV_DIR=""
LAST_PATH=""
BOOKMARK_LIST=()  # List to store multiple bookmarks
current_dir_tracker=$(pwd)  # Track the current directory
tab=$('\t')  # Proper tab setting
MODE="navigation"  # Flag to track the current mode
selected_item=""  # Track the selected file or directory
current_selection=0  # Track the current selected item in the list

# Print prompt at the top of the display
print_prompt() {
  echo "Select a number, press = to go to the last directory, Backspace for '..', '\\\\' twice to bookmark:"
  if [[ ${#BOOKMARK_LIST[@]} -gt 0 ]]; then
    echo -e "${NEON_YELLOW}Bookmarks:${NC}"
    for bookmark in "${BOOKMARK_LIST[@]}"; do
      echo -e "${NEON_YELLOW}$bookmark${NC}"
    done
  fi
  if [[ -n "$LAST_PATH" ]]; then
    echo -e "${NEON_BLUE}$LAST_PATH${NC}"
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
    # Navigate to the last directory
    if [[ -n "$LAST_PATH" ]]; then
      PREV_DIR=$(pwd)
      cd "$LAST_PATH"
      LAST_PATH="$PREV_DIR"
    else
      echo "No previous directory to return to."
    fi
  elif [[ "$main_choice" == "==" ]]; then
    # Navigate back to previous directory
    if [[ -n "$PREV_DIR" ]]; then
      LAST_PATH=$(pwd)
      cd "$PREV_DIR"
      PREV_DIR=""
    else
      echo "No previous directory to return to."
    fi
  elif [[ "$main_choice" == "BS" ]]; then
    # Backspace functionality to go up one directory
    LAST_PATH=$(pwd)
    PREV_DIR=$(pwd)
    cd ..
  elif [[ "$main_choice" == "\\\\" ]]; then
    # Bookmark the current directory if "\\" is pressed twice
    if [[ "$choice" == "\\\\" ]]; then
      BOOKMARK_LIST+=("$(pwd)")
      echo "Directory bookmarked: $(pwd)"
    fi
  elif [[ "$main_choice" -gt 0 && "$main_choice" -le $((dir_count + file_count)) ]]; then
    # Handle directory and file selection
    if [[ "$main_choice" -le $dir_count ]]; then
      selected_item="${dirs[$((main_choice-1))]}"
      PREV_DIR=$(pwd)
      cd "$selected_item"
    else
      selected_item="${files[$((main_choice-dir_count-1))]}"
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
  for term in "${exclude_terms[@]}"; do
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

# Function to display the directory and file lists
display_items_fileNav() {
  dirs=($(ls -d */ 2>/dev/null))
  files=($(ls -p | grep -v /))
  dir_count=${#dirs[@]}
  file_count=${#files[@]}
  max_items=$(( dir_count > file_count ? dir_count : file_count ))

  echo -e "${NEON_GREEN}Files${NC}$(printf '%*s' $((COLWIDTH - 5)) '')${NEON_RED}Directories${NC}"
  for ((i = 0; i < max_items; i++)); do
    if [ $i -lt $file_count ]; then
      if [ $((dir_count + i + 1)) -eq $current_selection ]; then
        printf "${NEON_GREEN}%2d. %-*s${NC} <---" $((dir_count + i + 1)) $COLWIDTH "${files[i]}"
      else
        printf "${NEON_GREEN}%2d. %-*s${NC}" $((dir_count + i + 1)) $COLWIDTH "${files[i]}"
      fi
    else
      printf "%-${COLWIDTH}s" ""
    fi

    if [ $i -lt "$dir_count" ]; then
      if [ $((i + 1)) -eq $current_selection ]; then
        printf "${NEON_RED}%2d. %s${NC}/ <---" $((i + 1)) "${dirs[i]}"
      else
        printf "${NEON_RED}%2d. %s${NC}/" $((i + 1)) "${dirs[i]}"
      fi
    fi
    echo ""
  done
}

# Active Reader for navigation input
active_reader() {
  while true; do
    read -p "Enter your choice: " -n 1 choice

    case "$choice" in
      0)
        clear
        MODE="menu"  # Switch to Menu Mode
        custom_action_menu  # Call the custom action menu
        ;;
      $'\x7f')  # Handle Backspace
        echo -ne "\033[1A\033[K"
        PREV_DIR=$(pwd)
        cd ..
        refresh_to_pseudo
        ;;
      '!')
        echo -ne "\033[1A\033[K"
        echo "Custom action for '!'"
        refresh_to_pseudo
        ;;
      '=')
        echo -ne "\033[1A\033[K"
        PREV_DIR=$(pwd)
        cd ..
        refresh_to_pseudo
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
      [1-9])
        read -n 2 -s more_choice
        choice+="$more_choice"
        read -s -n 1 final_enter$'\n'
        end_enter="$final_enter"$'\n'
        collect_items_fileNav "$choice" "$end_enter"$'\n'
        break
        ;;
      *)
        echo -ne "\033[1A\033[K"  # Move cursor up one line and clear it
        echo "Invalid input, please try again."
        refresh_to_pseudo  # Refresh the pseudo display on invalid input
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

# Handling Directory or File Selection Based on Choice
handle_choice_fileNav() {
  local choice="$1"
  local final_enter="$2"

  if [[ "$choice" == "=" ]]; then
    PREV_DIR=$(pwd)
    cd ..
    refresh_to_pseudo
  elif [[ "$choice" == "==" ]]; then
    if [[ -n "$PREV_DIR" ]]; then
      cd "$PREV_DIR"
      PREV_DIR=""
    else
      echo "No previous directory to return to."
    fi
    refresh_to_pseudo
  elif [[ "$choice" -gt 0 && "$choice" -le $((dir_count + file_count)) ]]; then
    if [[ "$choice" -le $dir_count ]]; then
      selected_item="${dirs[$((choice-1))]}"
      PREV_DIR=$(pwd)
      cd "$selected_item"
      refresh_to_pseudo
    else
      selected_item="${files[$((choice-dir_count-1))]}"
      MODE="file_action"  # Switch to file action mode
      file_action_menu  # Invoke the menu for file actions
    fi
  else
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
    echo "0) Go back to navigation"

    read -n 1 -s -p "Choose an action: " file_action

    case $file_action in
      1) content_to_clipboard ;;
      2) search_current_directory ;;
      3) edit_with_nano ;;
      4) extract_with_tar ;;
      5) display_and_copy_ls_la ;;
      6) delete_item ;;
      0) refresh_to_pseudo; MODE="navigation"; break ;;
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
    echo "4) Go back to navigation"

    read -n 1 -s -p "Choose an option: " menu_choice

    case $menu_choice in
      1) search_current_directory ;;
      2) display_and_copy_ls_la ;;
      3) read -p "Enter directory name: " dir_name
         mkdir "$dir_name"
         echo "Directory '$dir_name' created."
         ;;
      4 | $'\x7f' | '=' | 0)  # Backspace, =, and 0 to exit to pseudo display
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
    PREV_DIR=$(pwd)
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
