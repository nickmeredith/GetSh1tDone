# Git Authentication Setup for GitHub

You need to authenticate with GitHub to push your code. Here are your options:

## Option 1: Use GitHub CLI (Recommended - Easiest)

If you have GitHub CLI installed:

```bash
# Authenticate with GitHub
gh auth login

# Follow the prompts:
# - Choose GitHub.com
# - Choose HTTPS
# - Authenticate via web browser (easiest)
# - Login with your GitHub account

# Then push
git push -u origin main
```

If you don't have GitHub CLI, install it:
```bash
brew install gh
```

## Option 2: Use Personal Access Token (PAT)

1. **Create a Personal Access Token:**
   - Go to: https://github.com/settings/tokens
   - Click "Generate new token" → "Generate new token (classic)"
   - Give it a name like "GetSh1tDone"
   - Select scopes: Check `repo` (full control of private repositories)
   - Click "Generate token"
   - **Copy the token immediately** (you won't see it again!)

2. **Push using the token:**
   ```bash
   git push -u origin main
   # When prompted:
   # Username: nickmeredith
   # Password: [paste your token here]
   ```

3. **Or configure Git credential helper (saves token):**
   ```bash
   git config --global credential.helper osxkeychain
   git push -u origin main
   # Enter token as password (it will be saved)
   ```

## Option 3: Use SSH (More Secure)

1. **Check if you have SSH keys:**
   ```bash
   ls -la ~/.ssh
   ```

2. **Generate SSH key if needed:**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # Press Enter to accept default location
   # Optionally set a passphrase
   ```

3. **Add SSH key to GitHub:**
   ```bash
   # Copy your public key
   cat ~/.ssh/id_ed25519.pub
   # Copy the output
   ```
   
   Then:
   - Go to: https://github.com/settings/keys
   - Click "New SSH key"
   - Paste your public key
   - Click "Add SSH key"

4. **Update remote to use SSH:**
   ```bash
   git remote set-url origin git@github.com:nickmeredith/GetSh1tDone.git
   git push -u origin main
   ```

## Quick Fix: Make Sure Repository Exists

Before pushing, make sure the repository exists on GitHub:

1. Go to: https://github.com/new
2. Repository name: `GetSh1tDone`
3. Choose Public or Private
4. **DO NOT** initialize with README (you already have files)
5. Click "Create repository"

## After Authentication

Once authenticated, you can push:

```bash
git push -u origin main
```

Future pushes will be simpler:
```bash
git push
```


