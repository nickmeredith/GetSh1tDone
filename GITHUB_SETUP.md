# Setting Up GitHub for GetSh1tDone

This guide will help you push your GetSh1tDone project to GitHub.

## Step 1: Create a GitHub Repository

1. Go to [github.com](https://github.com) and sign in
2. Click the **"+"** icon in the top right → **"New repository"**
3. Fill in the details:
   - **Repository name**: `GetSh1tDone` (or your preferred name)
   - **Description**: "Productivity tool for organizing tasks using the Eisenhower Matrix"
   - **Visibility**: Choose **Public** or **Private**
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)
4. Click **"Create repository"**

## Step 2: Add All Your Files to Git

Run these commands in Terminal (from your project directory):

```bash
cd "/Users/nickmeredith/Library/Mobile Documents/com~apple~CloudDocs/IOS_Projects/GetSh1tDone"

# Add all files (respecting .gitignore)
git add .

# Check what will be committed
git status

# Commit all changes
git commit -m "Initial commit: GetSh1tDone app with Eisenhower Matrix"
```

## Step 3: Connect to GitHub

After creating the repository on GitHub, you'll see a page with setup instructions. Use the **"push an existing repository"** option:

```bash
# Add GitHub as remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/GetSh1tDone.git

# Or if you prefer SSH:
# git remote add origin git@github.com:YOUR_USERNAME/GetSh1tDone.git

# Verify the remote was added
git remote -v

# Push to GitHub
git branch -M main
git push -u origin main
```

## Step 4: Verify

1. Go to your GitHub repository page
2. You should see all your project files
3. Your code is now backed up on GitHub!

## Future Updates

Whenever you make changes:

```bash
# Check what changed
git status

# Add changed files
git add .

# Commit with a message
git commit -m "Description of your changes"

# Push to GitHub
git push
```

## Quick Commands Reference

```bash
# Check status
git status

# See what files are tracked
git ls-files

# View commit history
git log --oneline

# Pull latest changes (if working on multiple machines)
git pull

# Create a new branch
git checkout -b feature-name

# Switch back to main
git checkout main
```

## Troubleshooting

### If you get authentication errors:
- Use GitHub CLI: `gh auth login`
- Or set up SSH keys: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

### If files aren't being tracked:
- Check `.gitignore` isn't excluding them
- Use `git add -f filename` to force add

### If you need to update remote URL:
```bash
git remote set-url origin https://github.com/YOUR_USERNAME/GetSh1tDone.git
```


