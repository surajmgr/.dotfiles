# Dotfiles
This repo contains my personal dotfiles and configs. To set up your environment with these configurations, follow the instructions below.

## Prerequisites
Make sure you have the following tools installed on your system:
- Git
- GNU Stow
- Any other config related deps

## Installation
1. Clone the repo anywhere you want (Recommended: `~/.dotfiles`).
2. Pull the submodules:
   ```bash
   git submodule update --init --recursive
   ```
3. Use GNU Stow to create symlinks for the desired configurations. For example, for nvim:
   ```bash
   stow .config/nvim -t ~
   ```
   You can repeat this step for other configs as needed. As for the full integration, you can directly stow the whole repo:
   ```bash
   stow . -t ~
   ```
   Note: This will overwrite existing files in your home directory if they conflict with the dotfiles being stowed. Please back up any important files before proceeding.

## Updating
To update your dotfiles, navigate to the cloned repository and pull the latest changes:
```bash
git pull origin main
git submodule update --remote --merge
```
