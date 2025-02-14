#!/usr/bin/zsh

# Set the backup directory
BACKUP_DIR="$HOME/dotfiles_backup"

# Create the backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to ask for confirmation
ask_confirmation() {
  read -q "REPLY?Backup '$1'? (y/n): "
  [[ "$REPLY" =~ ^[yY](es)?$ ]]
}

# Loop through each file and directory in the current directory
for item in *; do
  # Skip the .git directory
  if [[ "$item" == ".git" ]]; then
    continue
  fi

  # Skip the backup directory
  if [[ "$item" == "$(basename "$BACKUP_DIR")" ]]; then
    continue
  fi

  # Handle .config directory differently
  if [[ "$item" == ".config" ]]; then
    echo "Skipping files inside .config directory."
    continue
  fi

  # Ask for confirmation before backing up
  if ask_confirmation "$item"; then
    # Backup the item
    if [ -d "$item" ]; then
      # If it's a directory, copy it recursively
      cp -r "$item" "$BACKUP_DIR/"
      echo "Backed up directory: $item"
    else
      # If it's a file, copy it
      cp "$item" "$BACKUP_DIR/"
      echo "Backed up file: $item"
    fi
  else
    echo "Skipped: $item"
  fi
done

echo "Backup complete. Files are located in: $BACKUP_DIR"
